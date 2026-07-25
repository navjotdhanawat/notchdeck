import XCTest
@testable import ClaudeNotchCore

final class TranscriptParserTests: XCTestCase {
    func testClaudeParserSumsUsageAndReadsModel() {
        let chunk = """
        {"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"input_tokens":10,"output_tokens":5,"cache_creation_input_tokens":2,"cache_read_input_tokens":1}}}
        {"type":"user","message":{"role":"user"}}
        {"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"input_tokens":3,"output_tokens":4}}}
        """
        let (model, usage) = ClaudeTranscriptParser().parse(chunk)
        XCTAssertEqual(model, "claude-opus-4-8")
        XCTAssertEqual(usage, TokenUsage(input: 13, output: 9, cacheCreation: 2, cacheRead: 1))
    }

    func testClaudePricingReturnsNilForUnknownModel() {
        XCTAssertNil(ClaudePricing().cost(model: "gpt-nope", tokens: TokenUsage(input: 1)))
        XCTAssertNotNil(ClaudePricing().cost(model: "claude-opus-4-8", tokens: TokenUsage(input: 1_000_000)))
    }
}
