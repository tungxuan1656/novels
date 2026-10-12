import Foundation
@testable import novels
import XCTest

// swiftlint:disable trailing_comma

@MainActor
final class AIStructuredResponseTests: XCTestCase {
    func testFinalJsonObjectsResolveForEveryTransport() throws {
        let fixtures: [(AIEndpointFamily, [String: Any])] = [
            (.chatCompletions, ["choices": [["finish_reason": "stop", "message": ["content": " {\"text\":\"ok\"} "]]]]),
            (.responses, ["status": "completed", "output_text": "{\"text\":\"ok\"}"]),
            (.anthropic, ["stop_reason": "end_turn", "content": [["type": "text", "text": "{\"text\":\"ok\"}"]]]),
        ]
        for (family, object) in fixtures {
            XCTAssertEqual(try resolve(object, family: family), #"{"text":"ok"}"#)
        }
    }

    func testReasoningOnlyJsonIsNotAcceptedAsStructuredAnswer() throws {
        let root: [String: Any] = ["choices": [["message": ["reasoning_content": "{\"text\":\"hidden\"}"]]]]
        XCTAssertNil(try resolve(root, family: .chatCompletions))
        let data = try JSONSerialization.data(withJSONObject: root)
        XCTAssertEqual(AIUnifiedResponse.resolve(data: data, family: .chatCompletions), #"{"text":"hidden"}"#)
    }

    func testRefusalAndIncompleteEnvelopesRejectEvenValidJsonText() throws {
        let fixtures: [(AIEndpointFamily, [String: Any])] = [
            (.chatCompletions, ["choices": [["finish_reason": "length", "message": ["content": "{}"]]]]),
            (.chatCompletions, ["choices": [["message": ["content": "{}", "refusal": "no"]]]]),
            (.responses, ["status": "incomplete", "output_text": "{}"]),
            (.responses, ["status": "completed", "output_text": "{}", "output": [
                ["type": "message", "content": [["type": "refusal", "refusal": "no"]]],
            ]]),
            (.anthropic, ["stop_reason": "max_tokens", "content": [["type": "text", "text": "{}"]]]),
        ]
        for (family, object) in fixtures {
            XCTAssertNil(try resolve(object, family: family))
        }
    }

    func testMalformedMarkdownArraysAndScalarContentReject() throws {
        for content in ["not-json", "```json\n{}\n```", "[]", "null", "42", "\"scalar\""] {
            XCTAssertNil(try resolve(["choices": [["message": ["content": content]]]], family: .chatCompletions))
        }
    }

    func testObjectShapeValidationIsNotSemanticSchemaValidation() throws {
        XCTAssertEqual(try resolve(["choices": [["message": ["content": "{}"]]]], family: .chatCompletions), "{}")
    }

    private func resolve(_ root: [String: Any], family: AIEndpointFamily) throws -> String? {
        try AIUnifiedResponse.resolve(
            data: JSONSerialization.data(withJSONObject: root),
            family: family,
            structured: true
        )
    }
}

// swiftlint:enable trailing_comma
