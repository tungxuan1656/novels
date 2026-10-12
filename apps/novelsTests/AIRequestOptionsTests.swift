import Foundation
@testable import novels
import XCTest

// swiftlint:disable trailing_comma

@MainActor
final class AIRequestOptionsTests: XCTestCase {
    private let schema = AIOutputSchema(
        name: "chapter_result",
        json: #"""
        {"type":"object","properties":{"text":{"type":"string"}},"required":["text"],"additionalProperties":false}
        """#
    )

    func testUnsetOptionsKeepLegacyBodiesAndPrompts() throws {
        for url in ["/chat/completions", "/responses", "/messages"] {
            let legacy = try body(url: url)
            let explicitUnset = try body(url: url, options: AIRequestOptions(provider: .gemini))
            XCTAssertEqual(legacy as NSDictionary, explicitUnset as NSDictionary)
            XCTAssertNil(legacy["reasoning_effort"])
            XCTAssertNil(legacy["reasoning"])
            XCTAssertNil(legacy["thinking"])
            XCTAssertNil(legacy["response_format"])
            let messages = legacy["messages"] as? [[String: Any]]
            let prompt = legacy["instructions"] as? String ?? legacy["system"] as? String
                ?? messages?.first?["content"] as? String
            XCTAssertEqual(prompt, "original prompt")
        }
    }

    func testChatProviderOnlyDepthAndDisableMappings() throws {
        for provider in [AIProvider.openai, .muse, .gemini] {
            for effort in AIThinkingEffort.allCases {
                let result = try body(options: AIRequestOptions(provider: provider, thinking: effort))
                XCTAssertEqual(result["reasoning_effort"] as? String, effort.rawValue)
            }
        }
        for provider in [AIProvider.deepseek, .glm, .minimax, .kimi] {
            let disabled = try body(options: AIRequestOptions(provider: provider, thinking: AIThinkingEffort.none))
            XCTAssertEqual((disabled["thinking"] as? [String: String])?["type"], "disabled")
            XCTAssertNil(disabled["reasoning_effort"])
            for effort in [AIThinkingEffort.low, .medium, .high] {
                let result = try body(options: AIRequestOptions(provider: provider, thinking: effort))
                XCTAssertEqual(result["reasoning_effort"] as? String, effort.rawValue)
                if provider == .kimi {
                    XCTAssertNil(result["thinking"])
                } else {
                    XCTAssertEqual((result["thinking"] as? [String: String])?["type"],
                                   provider == .minimax ? "adaptive" : "enabled")
                }
            }
        }
        let mimo = try body(options: AIRequestOptions(provider: .mimo, thinking: AIThinkingEffort.none))
        XCTAssertEqual((mimo["thinking"] as? [String: String])?["type"], "disabled")
        XCTAssertThrowsError(try body(options: AIRequestOptions(provider: .mimo, thinking: .low)))
        XCTAssertThrowsError(try body(options: AIRequestOptions(provider: .anthropic, thinking: .high)))
    }

    func testEndpointControlsTransportAndNeverRewritesLevels() throws {
        for provider in AIProvider.allCases where provider != .auto && provider != .mimo {
            for effort in AIThinkingEffort.allCases {
                let result = try body(
                    url: "/responses",
                    options: AIRequestOptions(provider: provider, thinking: effort)
                )
                XCTAssertEqual((result["reasoning"] as? [String: String])?["effort"], effort.rawValue)
                XCTAssertEqual(result["instructions"] as? String, "original prompt")
                XCTAssertNil(result["messages"])
            }
        }
        for provider in [AIProvider.anthropic, .minimax] {
            for effort in AIThinkingEffort.allCases {
                let result = try body(url: "/messages", options: AIRequestOptions(provider: provider, thinking: effort))
                XCTAssertEqual((result["thinking"] as? [String: String])?["type"],
                               effort == .none ? "disabled" : "adaptive")
                let output = result["output_config"] as? [String: String]
                XCTAssertEqual(output?["effort"], effort == .none ? nil : effort.rawValue)
                XCTAssertEqual(result["max_tokens"] as? Int, 1024)
            }
        }
        XCTAssertThrowsError(try body(url: "/messages", options: AIRequestOptions(provider: .gemini, thinking: .low)))
        XCTAssertThrowsError(try body(
            url: "/responses",
            options: AIRequestOptions(provider: .mimo, thinking: AIThinkingEffort.none)
        ))
    }

    func testCustomThinkingOwnsWholeGroupIncludingNativeGemini() throws {
        let overrides: [[String: Any]] = [
            ["thinking": ["type": "disabled"]], ["reasoning_effort": "low"],
            ["reasoning": ["effort": "none"]], ["output_config": ["effort": "low"]],
            ["thinking_config": ["thinking_budget": 0]],
            ["extra_body": ["google": ["thinking_config": ["thinking_budget": 1024]]]],
        ]
        for custom in overrides {
            let options = AIRequestOptions(provider: .anthropic, thinking: .high)
            XCTAssertTrue(try options.thinkingFields(family: .anthropic, extra: custom).isEmpty)
            let result = try body(url: "/messages", extra: custom, options: options)
            for (key, value) in custom {
                XCTAssertEqual(result[key] as? NSDictionary, value as? NSDictionary)
            }
            if custom["thinking"] == nil {
                XCTAssertNil(result["thinking"])
            }
        }
        let bypass = try body(extra: ["thinking": ["type": "enabled"]],
                              options: AIRequestOptions(provider: .mimo, thinking: .low))
        XCTAssertEqual((bypass["thinking"] as? [String: String])?["type"], "enabled")
    }

    func testReservedKeysAndTokenOverrideStayIntact() throws {
        let extra: [String: Any] = [
            "model": "wrong", "messages": [], "input": "wrong", "system": "wrong",
            "instructions": "wrong", "stream": true, "max_tokens": 8192,
        ]
        for url in ["/chat/completions", "/responses", "/messages"] {
            let result = try body(url: url, extra: extra)
            XCTAssertEqual(result["model"] as? String, "model-alias")
            XCTAssertEqual(result["stream"] as? Bool, false)
            if url == "/messages" {
                XCTAssertEqual(result["max_tokens"] as? Int, 8192)
                XCTAssertEqual(result["system"] as? String, "original prompt")
            }
            if url == "/responses" {
                XCTAssertEqual(result["input"] as? String, "chunk")
            }
        }
        XCTAssertThrowsError(try body(extra: ["invalid": Date()]))
    }

    func testSchemaFormatsPromptAndProviderModes() throws {
        for provider in [AIProvider.openai, .muse, .gemini, .kimi] {
            let result = try body(options: AIRequestOptions(provider: provider, outputSchema: schema))
            let format = try XCTUnwrap(result["response_format"] as? [String: Any])
            XCTAssertEqual(format["type"] as? String, "json_schema")
            let nested = try XCTUnwrap(format["json_schema"] as? [String: Any])
            XCTAssertEqual(nested["name"] as? String, "chapter_result")
            XCTAssertEqual(nested["strict"] as? Bool, true)
            XCTAssertEqual(nested["schema"] as? NSDictionary, try schema.object() as NSDictionary)
            let prompt = ((result["messages"] as? [[String: Any]])?.first?["content"] as? String) ?? ""
            XCTAssertTrue(prompt.hasPrefix("original prompt"))
            XCTAssertTrue(prompt.contains(schema.json))
        }
        for provider in [AIProvider.deepseek, .glm, .mimo] {
            let result = try body(options: AIRequestOptions(provider: provider, outputSchema: schema))
            XCTAssertEqual(result["response_format"] as? [String: String], ["type": "json_object"])
        }
        for url in ["/chat/completions", "/messages"] {
            let result = try body(url: url, options: AIRequestOptions(provider: .minimax, outputSchema: schema))
            XCTAssertNil(result["response_format"])
            XCTAssertNil((result["output_config"] as? [String: Any])?["format"])
        }
    }

    func testMiniMaxSchemaValidatesContainerWithoutAddingNativeFormat() throws {
        let options = AIRequestOptions(provider: .minimax, outputSchema: schema)
        for invalid: Any in ["wrong", NSNull(), []] {
            XCTAssertThrowsError(try body(url: "/messages", extra: ["output_config": invalid], options: options))
        }
        XCTAssertThrowsError(try body(
            url: "/messages",
            extra: ["output_config": ["format": ["type": "json_schema"]]],
            options: options
        ))
        let valid = try body(url: "/messages", extra: ["output_config": ["effort": "high"]], options: options)
        XCTAssertEqual(valid["output_config"] as? [String: String], ["effort": "high"])
    }

    func testNestedSchemaPreservesVerbosityEffortAndUnrelatedCustomFields() throws {
        let responses = try body(url: "/responses", extra: ["text": ["verbosity": "low"]],
                                 options: AIRequestOptions(provider: .muse, thinking: .high, outputSchema: schema))
        let text = try XCTUnwrap(responses["text"] as? [String: Any])
        XCTAssertEqual(text["verbosity"] as? String, "low")
        XCTAssertEqual((text["format"] as? [String: Any])?["type"] as? String, "json_schema")
        XCTAssertEqual((responses["reasoning"] as? [String: String])?["effort"], "high")
        let messages = try body(url: "/messages", extra: ["output_config": ["other": true]],
                                options: AIRequestOptions(
                                    provider: .anthropic,
                                    thinking: .medium,
                                    outputSchema: schema
                                ))
        let output = try XCTUnwrap(messages["output_config"] as? [String: Any])
        XCTAssertEqual(output["effort"] as? String, "medium")
        XCTAssertEqual(output["other"] as? Bool, true)
        XCTAssertEqual(
            (output["format"] as? [String: Any])?["schema"] as? NSDictionary,
            try schema.object() as NSDictionary
        )
    }

    func testConflictingFormatsAndInvalidSchemasFailBeforeSerialization() throws {
        let options = AIRequestOptions(provider: .openai, outputSchema: schema)
        XCTAssertThrowsError(try body(extra: ["response_format": ["type": "text"]], options: options))
        XCTAssertThrowsError(try body(
            url: "/responses",
            extra: ["text": ["format": ["type": "text"]]],
            options: options
        ))
        XCTAssertThrowsError(try body(url: "/responses", extra: ["text": "wrong"], options: options))
        let anthropic = AIRequestOptions(provider: .anthropic, outputSchema: schema)
        XCTAssertThrowsError(try body(url: "/messages", extra: ["output_config": NSNull()], options: anthropic))
        XCTAssertThrowsError(try body(url: "/messages", options: options))
        for invalid in [
            AIOutputSchema(name: "bad name", json: schema.json),
            AIOutputSchema(name: "valid", json: "not-json"),
            AIOutputSchema(name: "valid", json: #"{"type":"array"}"#),
        ] {
            XCTAssertThrowsError(try body(options: AIRequestOptions(outputSchema: invalid)))
        }
    }

    private func body(
        url: String = "/chat/completions",
        extra: [String: Any] = [:],
        options: AIRequestOptions = AIRequestOptions()
    ) throws -> [String: Any] {
        let data = try AIClient.makeRequestBodyData(model: "model-alias", prompt: "original prompt", chunk: "chunk",
                                                    extra: extra, urlString: "https://fixture.test" + url,
                                                    options: options)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

// swiftlint:enable trailing_comma
