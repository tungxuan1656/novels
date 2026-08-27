@testable import novels
import XCTest

final class HardeningRegressionTests: XCTestCase {
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
        return fileURL.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testProjectConfigIsIPhoneOnly() throws {
        let root = repoRoot()
        let pbxURL = root.appendingPathComponent("apps/novels.xcodeproj/project.pbxproj")
        let pbxPath = FileManager.default.fileExists(atPath: pbxURL.path)
            ? pbxURL.path : "apps/novels.xcodeproj/project.pbxproj"
        let pbx = try String(contentsOfFile: pbxPath, encoding: .utf8)
        // must be iPhone only, not 1,2
        XCTAssertTrue(pbx.contains("TARGETED_DEVICE_FAMILY = 1;"))
        XCTAssertFalse(pbx.contains("TARGETED_DEVICE_FAMILY = \"1,2\""))
        XCTAssertFalse(pbx.contains("TARGETED_DEVICE_FAMILY = 1,2"))
        XCTAssertTrue(pbx.contains("IPHONEOS_DEPLOYMENT_TARGET = 26.5;"))
        XCTAssertTrue(pbx.contains("DEVELOPMENT_TEAM = M5U4E4H84J;") || pbx.contains("DEVELOPMENT_TEAM = M5U4E4H84J"))
        XCTAssertFalse(pbx.contains("INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad"))
        XCTAssertFalse(pbx.lowercased().contains("~ipad"))
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

    @MainActor
    func testLibraryRowsHaveIdentifiersAndMinHeight() throws {
        let src = try source("apps/novels/Features/Library/LibraryView.swift")
        XCTAssertTrue(src.contains("accessibilityIdentifier(\"library.row."))
        XCTAssertTrue(src.contains("accessibilityLabel(\"Thêm sách\")"))
        XCTAssertTrue(src.contains("accessibilityLabel(\"Cài đặt\")"))
        XCTAssertTrue(src.contains("56") || src.contains("44") || src.contains("minHeight"))
    }

    @MainActor
    func testReaderControlsA11y() throws {
        let src = try source("apps/novels/Features/Reading/ReaderView.swift")
        XCTAssertTrue(src.contains("accessibilityIdentifier(\"prevButton\")"))
        XCTAssertTrue(src.contains("accessibilityLabel(\"Chương trước\")"))
        XCTAssertTrue(src.contains("accessibilityIdentifier(\"nextButton\")"))
        XCTAssertTrue(src.contains("accessibilityLabel(\"Chương sau\")"))
        XCTAssertTrue(src.contains("accessibilityIdentifier(\"typographyButton\")"))
        XCTAssertTrue(src.contains("accessibilityIdentifier(\"prefetchStatus\")"))
        XCTAssertTrue(src.contains("44") || src.contains("minHeight"))
    }

    func testContrastTokensUnchanged() throws {
        let src = try source("apps/novels/Resources/DesignTokens.swift")
        // tokens are defined as hex 0xXXXXXX; accept both #XXXXXX and 0x form
        XCTAssertTrue(src.contains("111111"))
        XCTAssertTrue(src.contains("6B7280"))
        XCTAssertTrue(src.contains("2563EB"))
        XCTAssertTrue(src.contains("FDFCF8"))
        XCTAssertTrue(src.contains("FFFFFF"))
    }

    func testBottomSheetHandleA11y() throws {
        let src = try source("apps/novels/SharedUI/BottomSheetView.swift")
        XCTAssertTrue(src.contains("DesignTokens.border") || src.lowercased().contains("handle"))
        // decorative handle should be hidden from VoiceOver
        XCTAssertTrue(src.contains("accessibilityHidden(true)"))
    }
}
