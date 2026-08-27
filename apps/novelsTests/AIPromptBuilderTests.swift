@testable import novels
import XCTest

final class AIPromptBuilderTests: XCTestCase {
    func testTranslatePromptKeepsHonorifics() {
        let prompt = AIPromptBuilder.prompt(for: .translate, actionsJSON: "")
        let lower = prompt.lowercased()
        XCTAssertTrue(
            lower.contains("ta") || prompt.contains("honorific") || prompt.contains("giữ nguyên")
        )
        XCTAssertTrue(prompt.contains("tự nhiên") || lower.contains("natural"))
        XCTAssertTrue(prompt.contains("100%") || prompt.contains("toàn bộ"))
    }

    func testTranslatePromptDefaultContainsBR0304() {
        let prompt = AIPromptBuilder.defaultPrompt(for: .translate)
        let hasHonorific = (prompt.contains("ta") && prompt.contains("ngươi")) || prompt.contains("honorific")
        XCTAssertTrue(hasHonorific)
        XCTAssertFalse(prompt.contains("50"))
    }

    func testSummaryPrompt50to60AndNoHallucination() {
        let prompt = AIPromptBuilder.prompt(for: .summary, actionsJSON: "")
        XCTAssertTrue(prompt.contains("50") && prompt.contains("60"))
        let lower = prompt.lowercased()
        XCTAssertTrue(
            prompt.contains("không bịa") || lower.contains("never invent") || lower.contains("no hallucination")
        )
        XCTAssertTrue(prompt.contains("cốt truyện") || lower.contains("plot"))
    }

    func testUsesActionsJSONWhenValid() {
        let json = """
        [{"key":"translate","name":"Dịch","prompt":"CUSTOM TRANSLATE PROMPT KEEP ta"},\
        {"key":"summary","name":"Tóm tắt","prompt":"CUSTOM SUMMARY 50-60"}]
        """
        XCTAssertEqual(AIPromptBuilder.prompt(for: .translate, actionsJSON: json), "CUSTOM TRANSLATE PROMPT KEEP ta")
        XCTAssertEqual(AIPromptBuilder.prompt(for: .summary, actionsJSON: json), "CUSTOM SUMMARY 50-60")
    }

    func testNoneReturnsEmpty() {
        XCTAssertEqual(AIPromptBuilder.prompt(for: .none, actionsJSON: ""), "")
    }
}
