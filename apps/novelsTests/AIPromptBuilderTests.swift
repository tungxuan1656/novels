@testable import novels
import XCTest

final class AIPromptBuilderTests: XCTestCase {
    func testRewritePromptUsesCustomPromptWhenNonEmpty() {
        let prompt = AIPromptBuilder.prompt(for: .rewrite, customPrompt: "Custom system prompt")
        XCTAssertEqual(prompt, "Custom system prompt")
    }

    func testRewritePromptFallsBackToDefaultWhenEmpty() {
        let prompt = AIPromptBuilder.prompt(for: .rewrite, customPrompt: "   ")
        XCTAssertEqual(prompt, SettingsDefaults.defaultPrompt)
    }

    func testDefaultPromptForRewriteContainsVietnamese() {
        let prompt = AIPromptBuilder.defaultPrompt(for: .rewrite)
        XCTAssertTrue(prompt.contains("tiếng Việt"))
    }

    func testNoneReturnsEmpty() {
        XCTAssertEqual(AIPromptBuilder.prompt(for: .none, customPrompt: "Custom prompt"), "")
        XCTAssertEqual(AIPromptBuilder.defaultPrompt(for: .none), "")
    }
}
