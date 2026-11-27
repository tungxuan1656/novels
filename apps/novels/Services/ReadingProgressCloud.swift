import CloudKit
import Foundation
#if os(macOS)
import Security
#endif

@MainActor
struct ReadingProgressCloud {
    let token: () -> String?
    let owner: () async throws -> String
    let fetch: (CKRecord.ID) async throws -> CKRecord
    let save: (CKRecord) async throws -> CKRecord

    static func live() -> Self? {
        let identifier = "iCloud.com.tungxuan.novels"
        #if os(macOS)
        // A Mac compile check can produce a runnable binary without iCloud rights.
        guard let task = SecTaskCreateFromSelf(nil),
              let containers = SecTaskCopyValueForEntitlement(
                  task, "com.apple.developer.icloud-container-identifiers" as CFString, nil
              ) as? [String], containers.contains(identifier),
              let services = SecTaskCopyValueForEntitlement(
                  task, "com.apple.developer.icloud-services" as CFString, nil
              ) as? [String], services.contains("CloudKit") else { return nil }
        #endif
        let container = CKContainer(identifier: identifier)
        return Self(
            token: {
                guard let token = FileManager.default.ubiquityIdentityToken,
                      let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: false)
                else { return nil }
                return SHA256.hex(data.base64EncodedString())
            },
            owner: { try await SHA256.hex(container.userRecordID().recordName) },
            fetch: { try await container.privateCloudDatabase.record(for: $0) },
            save: { record in
                let result = try await container.privateCloudDatabase.modifyRecords(
                    saving: [record], deleting: [], savePolicy: .ifServerRecordUnchanged
                )
                guard let saved = result.saveResults[record.recordID] else { throw CKError(.internalError) }
                return try saved.get()
            }
        )
    }
}
