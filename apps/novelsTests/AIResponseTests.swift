import Foundation
@testable import novels
import XCTest

@MainActor
final class AIResponseTests: XCTestCase {
    func testChatContentPrecedesReasoningAndBlankContentFallsBack() {
        XCTAssertEqual(resolve("""
        {"choices":[{"message":{"content":" answer ","reasoning_content":"fallback"}}]}
        """, family: .chatCompletions), "answer")
        XCTAssertEqual(resolve("""
        {"choices":[{"message":{"content":" ","reasoning_content":" fallback "}}]}
        """, family: .chatCompletions), "fallback")
    }

    func testResponsesOutputTextPrecedesBlocks() {
        XCTAssertEqual(resolve("""
        {"output_text":" direct ","output":[{"type":"message","content":[{"type":"output_text","text":"block"}]}]}
        """, family: .responses), "direct")
    }

    func testResponsesConcatenateOnlyMessageOutputTextBlocks() {
        XCTAssertEqual(resolve("""
        {"output_text":" ","output":[
          {"type":"reasoning","content":[{"type":"output_text","text":"hidden"}]},
          {"type":"message","content":[
            {"type":"refusal","refusal":"ignored"},
            {"type":"output_text","text":" first "},
            {"type":"output_text","text":7},
            {"type":"output_text","text":"second "}
          ]}
        ]}
        """, family: .responses), "first second")
    }

    func testAnthropicFiltersThinkingAndToolBlocks() {
        XCTAssertEqual(resolve("""
        {"content":[
          {"type":"thinking","text":"hidden"},
          {"type":"text","text":" first "},
          {"type":"tool_use","text":"ignored"},
          {"type":"text","text":"second "}
        ]}
        """, family: .anthropic), "first second")
    }

    func testMalformedAndNoTextResponsesReturnNil() {
        for family in [AIEndpointFamily.chatCompletions, .responses, .anthropic] {
            for json in ["not json", "{}", "[]", "null"] {
                XCTAssertNil(resolve(json, family: family))
            }
        }
        XCTAssertNil(resolve("""
        {"choices":[{"message":{"content":[],"tool_calls":[{"id":"tool","type":"function"}]}}]}
        """, family: .chatCompletions))
        XCTAssertNil(resolve("""
        {"output":[{"type":"message","content":[{"type":"refusal","refusal":"no"}]}]}
        """, family: .responses))
        XCTAssertNil(resolve("""
        {"content":[{"type":"thinking","text":"hidden"}]}
        """, family: .anthropic))
    }

    private func resolve(_ json: String, family: AIEndpointFamily) -> String? {
        AIUnifiedResponse.resolve(data: Data(json.utf8), family: family)
    }
}
