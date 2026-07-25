import XCTest
@testable import ClaudeNotchCore

final class AgentSeamsTests: XCTestCase {
    func testDefaultMapperDecodesAgentAndCoreFields() throws {
        let json = #"{"session_id":"s1","cwd":"/w","tool_name":"Bash","agent_id":"codex"}"#
        let e = try DefaultHookEventMapper().decode(Data(json.utf8), name: .preToolUse, now: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(e.agentID, "codex")
        XCTAssertEqual(e.toolName, "Bash")
    }

    // Compare parsed JSON (order-independent). DecisionEncoder does NOT use .sortedKeys, so a raw
    // Data byte-compare of two independent serializations is nondeterministic — assert semantics.
    private func json(_ d: Data?) -> NSDictionary? {
        guard let d else { return nil }
        return (try? JSONSerialization.jsonObject(with: d)) as? NSDictionary
    }

    func testSharedEncoderMatchesDecisionEncoder() {
        let enc = HookSpecificOutputEncoder()
        XCTAssertEqual(json(enc.stdoutJSON(for: .allow(scope: .once))),
                       json(DecisionEncoder.stdoutJSON(for: .allow(scope: .once))))
        XCTAssertEqual(json(enc.stdoutJSON(for: .deny(reason: "no"))),
                       json(DecisionEncoder.stdoutJSON(for: .deny(reason: "no"))))
        XCTAssertNil(enc.stdoutJSON(for: .passthrough))
        let answers = ["Q": "A"]
        let ti = Data(#"{"questions":[]}"#.utf8)
        XCTAssertEqual(json(enc.answerStdoutJSON(answers, originalToolInput: ti)),
                       json(DecisionEncoder.answerStdoutJSON(answers, originalToolInput: ti)))
    }
}
