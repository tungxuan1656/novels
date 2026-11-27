import CloudKit
import Foundation
@testable import novels
import XCTest

@MainActor
final class ReadingProgressStoreTests: XCTestCase {
    func testSlowSameAccountVerificationUploadsTheOnlyEdit() async throws {
        let defaults = try makeDefaults()
        let cloud = CloudProbe()
        cloud.suspendNextVerification = true
        let store = makeStore(defaults, cloud)
        let opening = Task { await store.progressOnOpen(bookId: "book") }
        await cloud.waitForLookup()
        let initial = await opening.value
        XCTAssertNil(initial) // Opening must not wait indefinitely for iCloud.

        store.save(bookId: "book", chapter: 4, anchor: nil)
        cloud.finishVerification(as: "account-a")
        await store.retryPending().value

        XCTAssertEqual(cloud.writes, [.init(owner: "account-a", chapter: 4)])
    }

    func testAccountChangeDiscardsAnEditAwaitingItsFirstVerification() async throws {
        let cloud = CloudProbe()
        cloud.suspendNextVerification = true
        let store = try makeStore(makeDefaults(), cloud)
        store.save(bookId: "book", chapter: 4, anchor: nil)
        await cloud.waitForLookup()

        cloud.token = "token-b"
        cloud.owner = "account-b"
        await store.accountChanged().value
        cloud.finishVerification(as: "account-a")
        let reopened = await store.progressOnOpen(bookId: "book")

        XCTAssertEqual(reopened?.progress.chapter, 4)
        XCTAssertTrue(cloud.writes.isEmpty)
    }

    func testRestartWhileOfflineQueuesOnlyForThePreviouslyVerifiedAccount() async throws {
        let defaults = try makeDefaults()
        let cloud = CloudProbe()
        let first = makeStore(defaults, cloud)
        await first.retryPending().value // Bind the local token while online.

        cloud.online = false
        let restarted = makeStore(defaults, cloud)
        restarted.save(bookId: "book", chapter: 5, anchor: nil)
        let offline = await restarted.progressOnOpen(bookId: "book")
        XCTAssertEqual(offline?.progress.chapter, 5)
        XCTAssertTrue(cloud.writes.isEmpty)

        cloud.token = "token-b"
        cloud.owner = "account-b"
        cloud.online = true
        await restarted.accountChanged().value
        XCTAssertTrue(cloud.writes.isEmpty)

        cloud.token = "token-a"
        cloud.owner = "account-a"
        await restarted.accountChanged().value
        XCTAssertEqual(cloud.writes, [.init(owner: "account-a", chapter: 5)])
    }

    func testConditionalConflictRefetchesAndRespectsNewerCloudProgress() async throws {
        let cloud = CloudProbe()
        let store = try makeStore(makeDefaults(), cloud)
        await store.retryPending().value
        cloud.conflictWith = ReadingProgress(chapter: 7, anchor: nil, updatedAt: .now.addingTimeInterval(60))

        store.save(bookId: "book", chapter: 4, anchor: nil)
        let reopened = await store.progressOnOpen(bookId: "book")

        XCTAssertEqual(reopened?.progress.chapter, 7)
        XCTAssertEqual(reopened?.isLocal, false)
        XCTAssertEqual(cloud.saveAttempts, 1)
        XCTAssertTrue(cloud.writes.isEmpty)
    }

    func testMissingCloudLeavesCheckpointsUsableLocally() async throws {
        let store = try ReadingProgressStore(defaults: makeDefaults(), cloud: nil, chapterCount: { _ in 10 })
        store.save(bookId: "book", chapter: 6, anchor: nil)
        let reopened = await store.progressOnOpen(bookId: "book")
        XCTAssertEqual(reopened?.progress.chapter, 6)
        XCTAssertEqual(reopened?.isLocal, true)
    }

    func testEditWithoutAnyAccountEvidenceStaysLocal() async throws {
        let cloud = CloudProbe()
        cloud.token = nil
        let store = try makeStore(makeDefaults(), cloud)
        store.save(bookId: "book", chapter: 6, anchor: nil)
        let reopened = await store.progressOnOpen(bookId: "book")
        XCTAssertEqual(reopened?.progress.chapter, 6)
        XCTAssertTrue(cloud.writes.isEmpty)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suite = "ReadingProgressStoreTests.\(UUID().uuidString)"
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    private func makeStore(_ defaults: UserDefaults, _ cloud: CloudProbe) -> ReadingProgressStore {
        ReadingProgressStore(defaults: defaults, cloud: cloud.dependencies, chapterCount: { _ in 10 })
    }
}

@MainActor
private final class CloudProbe {
    struct Write: Equatable {
        let owner: String
        let chapter: Int
    }

    var online = true
    var token: String? = "token-a"
    var owner = "account-a"
    var suspendNextVerification = false
    var conflictWith: ReadingProgress?
    private(set) var saveAttempts = 0
    private(set) var writes: [Write] = []
    private var remote: ReadingProgress?
    private var lookupStarted: CheckedContinuation<Void, Never>?
    private var verification: CheckedContinuation<String, Never>?

    var dependencies: ReadingProgressCloud {
        ReadingProgressCloud(
            token: { self.token },
            owner: { try await self.verify() },
            fetch: { id in
                guard let remote = self.remote else { throw CKError(.unknownItem) }
                let record = CKRecord(recordType: "ReadingProgress", recordID: id)
                record["checkpoint"] = try JSONEncoder().encode(remote) as NSData
                return record
            },
            save: { record in
                self.saveAttempts += 1
                if let conflict = self.conflictWith {
                    self.conflictWith = nil
                    self.remote = conflict
                    throw CKError(.serverRecordChanged)
                }
                let bytes = try XCTUnwrap(record["checkpoint"] as? Data)
                let progress = try XCTUnwrap(ReadingProgress.decode(bytes))
                self.writes.append(Write(owner: self.owner, chapter: progress.chapter))
                return record
            }
        )
    }

    func waitForLookup() async {
        if verification == nil {
            await withCheckedContinuation { lookupStarted = $0 }
        }
    }

    func finishVerification(as owner: String) {
        let pending = verification
        verification = nil
        pending?.resume(returning: owner)
    }

    private func verify() async throws -> String {
        guard online else { throw CKError(.networkUnavailable) }
        guard suspendNextVerification else { return owner }
        suspendNextVerification = false
        return await withCheckedContinuation {
            verification = $0
            lookupStarted?.resume()
            lookupStarted = nil
        }
    }
}
