// swiftlint:disable file_length
@testable import novels
import XCTest

final class HardeningRegressionTests: XCTestCase {
    private func repoRoot() -> URL {
        let pwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appsPbx = pwd.appendingPathComponent("apps/novels.xcodeproj/project.pbxproj").path
        if FileManager.default.fileExists(atPath: appsPbx) {
            return pwd
        }
        if FileManager.default.fileExists(atPath: pwd.appendingPathComponent("novels.xcodeproj/project.pbxproj").path) {
            return pwd.deletingLastPathComponent()
        }
        let fileURL = URL(fileURLWithPath: #filePath)
        var current = fileURL.deletingLastPathComponent()
        for _ in 0 ..< 8 {
            let candidate = current.appendingPathComponent("apps/novels.xcodeproj/project.pbxproj")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return current
            }
            let directCandidate = current.appendingPathComponent("novels.xcodeproj/project.pbxproj")
            if FileManager.default.fileExists(atPath: directCandidate.path) {
                return current.deletingLastPathComponent()
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
        }
        return pwd
    }

    func testProjectConfigIsIPhoneOnly() throws {
        let root = repoRoot()
        let pbxURL = root.appendingPathComponent("apps/novels.xcodeproj/project.pbxproj")
        let pbxPath = FileManager.default.fileExists(atPath: pbxURL.path)
            ? pbxURL.path : "apps/novels.xcodeproj/project.pbxproj"
        let pbx = try String(contentsOfFile: pbxPath, encoding: .utf8)
        // 3 targets (novels, novelsTests, novelsUITests) × 2 configs (Debug/Release) = 6 occurrences.
        let familyCount = pbx.components(separatedBy: "TARGETED_DEVICE_FAMILY = 1;").count - 1
        XCTAssertEqual(familyCount, 6, "Expected 6 TARGETED_DEVICE_FAMILY = 1; got \(familyCount)")
        XCTAssertFalse(pbx.contains("TARGETED_DEVICE_FAMILY = \"1,2\""))
        XCTAssertFalse(pbx.contains("TARGETED_DEVICE_FAMILY = 1,2"))
        XCTAssertFalse(pbx.contains("TARGETED_DEVICE_FAMILY = \"1, 2\""))
        let deploymentCount = pbx.components(separatedBy: "IPHONEOS_DEPLOYMENT_TARGET = 26.5;").count - 1
        XCTAssertEqual(deploymentCount, 6, "Expected 6 IPHONEOS_DEPLOYMENT_TARGET = 26.5; got \(deploymentCount)")
        XCTAssertTrue(pbx.contains("DEVELOPMENT_TEAM = M5U4E4H84J;") || pbx.contains("DEVELOPMENT_TEAM = M5U4E4H84J"))
        // Vector 1: pbxproj build setting insertion (case-sensitive, underscore, not tilde)
        XCTAssertFalse(
            pbx.contains("INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad"),
            "pbx must not contain INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad"
        )
        XCTAssertFalse(
            pbx.contains("INFOPLIST_KEY_UISupportedInterfaceOrientations~iPad"),
            "pbx must not contain tilde iPad variant"
        )
        // Vector 2: Info.plist ~ipad key insertion — check file directly
        let plistCandidate = root.appendingPathComponent("apps/novels/Info.plist")
        let plistURL = FileManager.default.fileExists(atPath: plistCandidate.path)
            ? plistCandidate : URL(fileURLWithPath: "apps/novels/Info.plist")
        let plistText = try String(contentsOf: plistURL, encoding: .utf8)
        XCTAssertFalse(
            plistText.contains("UISupportedInterfaceOrientations~ipad"),
            "Info.plist must not contain ~ipad orientation"
        )
        XCTAssertFalse(
            plistText.contains("UISupportedInterfaceOrientations~iPad"),
            "Info.plist must not contain ~iPad case variant"
        )
        XCTAssertFalse(
            plistText.contains("INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad"),
            "Info.plist text must not contain iPad orientation build key"
        )
    }

    func testInfoPlistATSAndLaunch() throws {
        // verify bundle plist from app target (use Bundle.main for app, not test host)
        // For unit, read file directly
        let root = repoRoot()
        let candidate = root.appendingPathComponent("apps/novels/Info.plist")
        let url = FileManager.default.fileExists(atPath: candidate.path)
            ? candidate : URL(fileURLWithPath: "apps/novels/Info.plist")
        let data = try Data(contentsOf: url)
        guard let plist = try PropertyListSerialization
            .propertyList(from: data, options: [], format: nil) as? [String: Any]
        else {
            XCTFail("Info.plist is not a dictionary")
            return
        }
        XCTAssertEqual(plist["LSRequiresIPhoneOS"] as? Bool, true)
        XCTAssertNotNil(plist["UILaunchScreen"])
        let ats = plist["NSAppTransportSecurity"] as? [String: Any]
        let domains = ats?["NSExceptionDomains"] as? [String: Any]
        XCTAssertNotNil(domains?["localhost"])
        XCTAssertNil(domains?["example.com"])
        // iPhone-only: should not contain iPad-only interface orientation when family=1
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(text.contains("UISupportedInterfaceOrientations~ipad"))
        XCTAssertFalse(text.contains("UISupportedInterfaceOrientations~iPad"))
    }
}

final class HardeningA11yTests: XCTestCase {
    private func repoRoot() -> URL {
        let fileURL = URL(fileURLWithPath: #filePath)
        var current = fileURL.deletingLastPathComponent()
        for _ in 0 ..< 6 {
            let candidate = current.appendingPathComponent("apps/novels.xcodeproj/project.pbxproj")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
        }
        return fileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func source(_ relative: String) throws -> String {
        let root = repoRoot()
        let candidate = root.appendingPathComponent(relative)
        let path = FileManager.default.fileExists(atPath: candidate.path) ? candidate.path : relative
        return try String(contentsOfFile: path, encoding: .utf8)
    }

    private func stripped(_ source: String) -> String {
        var result = source
        if let regex = try? NSRegularExpression(
            pattern: "/\\*.*?\\*/",
            options: [.dotMatchesLineSeparators]
        ) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        let lines = result.components(separatedBy: "\n")
        let withoutLineComments = lines.map { line -> String in
            if let range = line.range(of: "//") {
                return String(line[..<range.lowerBound])
            }
            return line
        }
        return withoutLineComments.joined(separator: "\n")
    }

    @MainActor
    func testLibraryRowsHaveIdentifiersAndMinHeight() throws {
        let src = try source("apps/novels/Features/Library/LibraryView.swift")
        let code = stripped(src)
        XCTAssertTrue(code.contains("accessibilityIdentifier(\"library.row."))
        XCTAssertTrue(code.contains("accessibilityLabel(\"Thêm sách\")"))
        XCTAssertTrue(code.contains("accessibilityLabel(\"Cài đặt\")"))
        let hasHitTarget = code.contains("a11yHitTarget()")
        let hasFrame44 = code.contains("frame(minHeight: 44") || code.contains("frame(minHeight:44")
            || code.contains("frame(minWidth: 44")
        let hasContentShape = code.contains("contentShape(Rectangle()")
        XCTAssertTrue(
            hasHitTarget || (hasFrame44 && hasContentShape),
            "Toolbar/rows must provide 44pt hit target via a11yHitTarget() or frame(44)+contentShape outside comments"
        )
    }

    @MainActor
    func testReaderControlsA11y() throws {
        let src = try source("apps/novels/Features/Reading/ReaderView.swift")
        let code = stripped(src)
        XCTAssertTrue(code.contains("accessibilityIdentifier(\"prevButton\")"))
        XCTAssertTrue(code.contains("accessibilityLabel(\"Chương trước\")"))
        XCTAssertTrue(code.contains("accessibilityIdentifier(\"nextButton\")"))
        XCTAssertTrue(code.contains("accessibilityLabel(\"Chương sau\")"))
        XCTAssertTrue(code.contains("accessibilityIdentifier(\"typographyButton\")"))
        XCTAssertTrue(code.contains("accessibilityIdentifier(\"prefetchStatus\")"))
        let hasHitTarget = code.contains("a11yHitTarget()")
        let hasFrame44 = code.contains("frame(minHeight: 44") || code.contains("frame(minHeight:44")
            || code.contains("frame(minWidth: 44")
        let hasContentShape = code.contains("contentShape(Rectangle()")
        XCTAssertTrue(
            hasHitTarget || (hasFrame44 && hasContentShape),
            "Reader controls must have 44pt hit target via a11yHitTarget() or frame(44)+contentShape outside comments"
        )
    }

    func testContrastTokensUnchanged() throws {
        let src = try source("apps/novels/Resources/DesignTokens.swift")
        let code = stripped(src)
        // Check hex literal with 0x prefix outside comments to avoid comment bypass.
        XCTAssertTrue(code.contains("0x111111"), "DesignTokens.text 0x111111 missing outside comments")
        XCTAssertTrue(code.contains("0x6B7280"), "DesignTokens.muted 0x6B7280 missing outside comments")
        XCTAssertTrue(code.contains("0x2563EB"), "DesignTokens.accent 0x2563EB missing outside comments")
        XCTAssertTrue(code.contains("0xF5F1E5"), "DesignTokens.backgroundPaper 0xF5F1E5 missing outside comments")
        XCTAssertTrue(code.contains("0xFFFFFF"), "DesignTokens.backgroundWhite 0xFFFFFF missing outside comments")
    }

    func testBottomSheetHandleA11y() throws {
        let src = try source("apps/novels/SharedUI/BottomSheetView.swift")
        let code = stripped(src)
        XCTAssertTrue(code.contains("DesignTokens.border"), "Handle should use DesignTokens.border outside comments")
        XCTAssertTrue(code.contains("Capsule()"), "Handle should be Capsule outside comments")
        // decorative handle should be hidden from VoiceOver
        XCTAssertTrue(code.contains("accessibilityHidden(true)"))
    }
}

// MARK: - Hardening Edge Sweep (Task 3)

// swiftlint:disable:next type_body_length
final class HardeningEdgeTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        AIMockURLProtocol.handler = nil
    }

    /// 1) offline — Library scan works without network, no URLSession call
    func testOfflineLibraryScan() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmp.appendingPathComponent("books/test-slug/chapters"),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmp) }
        let bookJSON = #"{"id":"test-slug","name":"Offline Book","author":"A","count":1,"references":["C1"]}"#
        try bookJSON.write(
            to: tmp.appendingPathComponent("books/test-slug/book.json"),
            atomically: true,
            encoding: .utf8
        )
        try "<p>Hello offline</p>".write(
            to: tmp.appendingPathComponent("books/test-slug/chapters/chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        let repo = FileBookRepository(root: tmp.appendingPathComponent("books"), fileManager: .default)
        let books = try repo.listBooks()
        XCTAssertEqual(books.count, 1)
        XCTAssertEqual(books.first?.id, "test-slug")
        let html = try repo.chapterHTML(slug: "test-slug", number: 1)
        XCTAssertTrue(html.contains("Hello"))
    }

    /// 2) invalid ZIP — zip-slip rejected; valid wrapper tolerated via hygiene
    func testInvalidZIPStillRejected() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let slipData = HardeningEdgeTests.makeZipSlipData()
        let zipURL = tmp.appendingPathComponent("slip.zip")
        try slipData.write(to: zipURL)
        let outDir = tmp.appendingPathComponent("out")
        do {
            try FileManager.default.unzipItem(at: zipURL, to: outDir)
            XCTFail("Expected zip-slip traversal error for ../evil.txt")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NSCocoaErrorDomain, "Zip-slip must throw CocoaError")
            XCTAssertEqual(
                nsError.code,
                CocoaError.fileReadCorruptFile.rawValue,
                "Zip-slip must map to fileReadCorruptFile (traversal), not generic error"
            )
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: outDir.appendingPathComponent("evil.txt").path),
                "evil.txt must not exist inside out"
            )
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: tmp.appendingPathComponent("evil.txt").path),
                "evil.txt must not escape to tmp via traversal"
            )
        }
        // valid sample with __MACOSX ignored is tolerated (resolver flattens hygiene)
        let wrapperURL = tmp.appendingPathComponent("wrapper.zip")
        try TolerantFixtures.makeWrapperWithMacOSXAndFlag08(at: wrapperURL, id: "valid", count: 1)
        let out = tmp.appendingPathComponent("wrapper-out")
        XCTAssertNoThrow(try FileManager.default.unzipItem(at: wrapperURL, to: out))
        let canonical = FileManager.default.resolveCanonicalRoot(at: out)
        XCTAssertTrue(ZipValidator.isValidRoot(at: canonical))
    }

    /// 3) missing chapter — Reader shows error without crash, navigation still works
    @MainActor
    func testMissingChapterShowsErrorWithoutCrash() async throws {
        // Use a mock repository that reports book exists but chapter 2 missing
        struct MissingRepo: BookRepository {
            func listBooks() throws -> [Book] {
                []
            }

            func book(slug: String) throws -> Book? {
                Book(id: "miss", name: "Miss", author: "A", count: 3, references: ["C1", "C2", "C3"])
            }

            func chapterHTML(slug: String, number: Int) throws -> String {
                if number == 2 {
                    throw BookRepositoryError.missingChapterFile(slug: slug, number: number)
                }
                return "<p>C\(number)</p>"
            }

            func save(validatedRoot: URL, slug: String) throws {}
            func deleteBook(slug: String) throws {}
        }
        let repo = MissingRepo()
        let suite = try XCTUnwrap(UserDefaults(suiteName: "edge.\(UUID().uuidString)"))
        let store = SettingsStore(userDefaults: suite)
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let vm = ReaderViewModel(bookId: "miss", repository: repo, settingsStore: store, cache: cache)
        vm.chapterNumber = 2
        await vm.load()
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.errorMessage?.contains("Không tìm thấy chương") ?? false)
        // goTo still works without crash
        await vm.goToChapter(3)
        XCTAssertEqual(vm.chapterNumber, 3)
    }

    /// 4) invalid JSON headers/body — AI merge ignores bad JSON, request succeeds stored verbatim
    @MainActor
    func testInvalidJSONHeadersBodyIgnored() async throws {
        let suite = try XCTUnwrap(UserDefaults(suiteName: "edge2.\(UUID().uuidString)"))
        let store = SettingsStore(userDefaults: suite)
        store.aiCustomHeadersJSON = "not json {"
        store.aiExtraBodyJSON = "{ broken"
        store.save()
        XCTAssertEqual(store.aiCustomHeadersJSON, "not json {")
        XCTAssertTrue(store.effectiveHeaders().isEmpty)
        XCTAssertTrue(store.effectiveExtraBody().isEmpty)
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AIMockURLProtocol.self]
        AIMockURLProtocol.handler = { req in
            XCTAssertNil(req.value(forHTTPHeaderField: "X-Bad"))
            let json = #"{"choices":[{"message":{"content":"ok"}}]}"#
            return (
                HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                json.data(using: .utf8)!
            )
        }
        let client = AIClient(settings: store, session: URLSession(configuration: config))
        let svc = AIReadingService(cache: cache, client: client, settings: store)
        let out = try await svc.processedContent(
            bookId: "s",
            chapterNumber: 1,
            mode: .translate,
            rawText: String(repeating: "a", count: 800)
        )
        XCTAssertEqual(out, "ok")
        XCTAssertEqual(store.aiCustomHeadersJSON, "not json {")
    }

    /// 5) cache clear immediate — countAll / count / bookIds reflect 0 after clearAll/clear(bookId)
    func testCacheClearImmediate() throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let now = Date()
        try cache.upsert(ProcessedChapter(
            bookId: "a",
            chapterNumber: 1,
            mode: .translate,
            content: "c1",
            contentHash: "h1",
            createdAt: now,
            updatedAt: now
        ))
        try cache.upsert(ProcessedChapter(
            bookId: "a",
            chapterNumber: 2,
            mode: .translate,
            content: "c2",
            contentHash: "h2",
            createdAt: now,
            updatedAt: now
        ))
        XCTAssertEqual(try cache.countAll(), 2)
        try cache.clear(bookId: "a")
        XCTAssertEqual(try cache.countAll(), 0)
        XCTAssertEqual(try cache.count(bookId: "a"), 0)
        try cache.upsert(ProcessedChapter(
            bookId: "b",
            chapterNumber: 1,
            mode: .summary,
            content: "s1",
            contentHash: "h3",
            createdAt: now,
            updatedAt: now
        ))
        try cache.clearAll()
        XCTAssertEqual(try cache.countAll(), 0)
    }

    /// 6) prefetch cancel — chapter/mode change cancels task via PrefetchManager.cancel()
    @MainActor
    func testPrefetchCancelOnChange() async throws {
        let cache = try SQLiteProcessedChapterCache.inMemory()
        let suite = try XCTUnwrap(UserDefaults(suiteName: "edge3.\(UUID().uuidString)"))
        let store = SettingsStore(userDefaults: suite)
        store.prefetchCount = 5
        store.save()
        let repo = MockBookRepo(slug: "p", count: 10)
        let tracking = TrackingAIClient()
        tracking.delayPerCall = 300_000_000
        let svc = tracking.service(cache: cache, settings: store)
        let mgr = PrefetchManager()
        await mgr.start(
            bookId: "p",
            currentChapter: 1,
            totalChapters: 10,
            mode: .translate,
            settings: store,
            cache: cache,
            aiService: svc,
            repository: repo
        )
        try? await Task.sleep(nanoseconds: 400_000_000)
        await mgr.cancel()
        try? await Task.sleep(nanoseconds: 400_000_000)
        let status = await mgr.currentStatus()
        XCTAssertFalse(status.isRunning)
        let count = try cache.countAll()
        XCTAssertTrue(count < 5, "count \(count) should be <5")
        XCTAssertTrue(tracking.calls.count < 5, "calls \(tracking.calls) should be <5")
    }

    /// 7) kill-on-Reading resume — ReadingSession survives relaunch via UserDefaults
    @MainActor
    func testKillOnReadingResume() throws {
        let suiteName = "kill.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let store = SettingsStore(userDefaults: suite)
        store.session = ReadingSession(bookId: "resume-slug", onScreen: true, offset: 42.5, chapterNumber: 2)
        store.save()
        // recreate store as if app killed and relaunched
        let suite2 = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let store2 = SettingsStore(userDefaults: suite2)
        XCTAssertEqual(store2.session?.bookId, "resume-slug")
        XCTAssertEqual(store2.session?.onScreen, true)
        XCTAssertEqual(store2.session?.offset ?? 0, 42.5, accuracy: 0.1)
        XCTAssertEqual(store2.session?.chapterNumber, 2)
        // Router restore check
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmp.appendingPathComponent("resume-slug/chapters"),
            withIntermediateDirectories: true
        )
        let resumeJSON = #"{"id":"resume-slug","name":"R","author":"A","count":1,"references":["C1"]}"#
        try resumeJSON.write(
            to: tmp.appendingPathComponent("resume-slug/book.json"),
            atomically: true,
            encoding: .utf8
        )
        try "<p>hi</p>".write(
            to: tmp.appendingPathComponent("resume-slug/chapters/chapter-1.html"),
            atomically: true,
            encoding: .utf8
        )
        let repo = FileBookRepository(root: tmp, fileManager: .default)
        let router = Router(settingsStore: store2, repository: repo)
        router.restoreInitialRoute()
        XCTAssertEqual(router.path.count, 1)
        try? FileManager.default.removeItem(at: tmp)
    }

    // MARK: - Helpers

    // swiftlint:disable:next function_body_length
    static func makeZipSlipData() -> Data {
        var data = Data()
        // Local header with traversal name — use correct CRC so traversal is the only rejection reason.
        let name = "../evil.txt"
        let nameData = name.data(using: .utf8)!
        let content = Data("evil".utf8)
        // Compute correct CRC32 for payload; ensures failure is traversal, not CRC mismatch.
        let crc: UInt32 = {
            let table: [UInt32] = (0 ..< 256).map { idx in
                var crcVal = UInt32(idx)
                for _ in 0 ..< 8 {
                    crcVal = (crcVal & 1) != 0 ? (crcVal >> 1) ^ 0xEDB8_8320 : crcVal >> 1
                }
                return crcVal
            }
            var crcValue: UInt32 = 0xFFFF_FFFF
            for byte in content {
                crcValue = (crcValue >> 8) ^ table[Int((crcValue ^ UInt32(byte)) & 0xFF)]
            }
            return crcValue ^ 0xFFFF_FFFF
        }()
        func append16(_ value: UInt16, to target: inout Data) {
            var le = value.littleEndian
            target.append(Data(bytes: &le, count: 2))
        }

        func append32(_ value: UInt32, to target: inout Data) {
            var le = value.littleEndian
            target.append(Data(bytes: &le, count: 4))
        }

        var local = Data()
        append32(0x0403_4B50, to: &local)
        append16(20, to: &local)
        append16(0, to: &local)
        append16(0, to: &local)
        append16(0, to: &local)
        append16(0, to: &local)
        append32(crc, to: &local)
        append32(UInt32(content.count), to: &local)
        append32(UInt32(content.count), to: &local)
        append16(UInt16(nameData.count), to: &local)
        append16(0, to: &local)
        local.append(nameData)
        local.append(content)

        var central = Data()
        append32(0x0201_4B50, to: &central)
        append16(20, to: &central)
        append16(20, to: &central)
        append16(0, to: &central)
        append16(0, to: &central)
        append16(0, to: &central)
        append16(0, to: &central)
        append32(crc, to: &central)
        append32(UInt32(content.count), to: &central)
        append32(UInt32(content.count), to: &central)
        append16(UInt16(nameData.count), to: &central)
        append16(0, to: &central)
        append16(0, to: &central)
        append16(0, to: &central)
        append16(0, to: &central)
        append32(0, to: &central)
        append32(0, to: &central)
        central.append(nameData)

        var eocd = Data()
        append32(0x0605_4B50, to: &eocd)
        append16(0, to: &eocd)
        append16(0, to: &eocd)
        append16(1, to: &eocd)
        append16(1, to: &eocd)
        append32(UInt32(central.count), to: &eocd)
        append32(UInt32(local.count), to: &eocd)
        append16(0, to: &eocd)

        data.append(local)
        data.append(central)
        data.append(eocd)
        return data
    }
}
