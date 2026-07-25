import XCTest
@testable import ClaudeNotchCore

final class HookEventTests: XCTestCase {
    private func decode(_ json: String, _ name: HookEventName) throws -> HookEvent {
        try HookEvent.decode(Data(json.utf8), name: name, now: Date(timeIntervalSince1970: 100))
    }

    func testDecodesCoreFieldsAndIgnoresUnknown() throws {
        let e = try decode(#"""
        {"session_id":"abc","cwd":"/w/proj","tool_name":"Bash",
         "transcript_path":"/t.jsonl","some_future_field":42,
         "env":{"ITERM_SESSION_ID":"w0t1p0:UUID-1","TERM_PROGRAM":"iTerm.app","PID":"123"}}
        """#, .preToolUse)
        XCTAssertEqual(e.name, .preToolUse)
        XCTAssertEqual(e.sessionID, "abc")
        XCTAssertEqual(e.cwd, "/w/proj")
        XCTAssertEqual(e.toolName, "Bash")
        XCTAssertEqual(e.transcriptPath, "/t.jsonl")
        XCTAssertEqual(e.env.values["ITERM_SESSION_ID"], "w0t1p0:UUID-1")
        XCTAssertEqual(e.env.termProgram, "iTerm.app")
        XCTAssertEqual(e.env.pid, 123)
    }

    func testMatcherAndMissingEnvTolerated() throws {
        let e = try decode(#"{"session_id":"x","cwd":"/w","matcher":"permission_prompt"}"#, .notification)
        XCTAssertEqual(e.matcher, "permission_prompt")
        XCTAssertNil(e.env.values["ITERM_SESSION_ID"])
        XCTAssertNil(e.toolName)
    }

    func testMissingSessionIDThrows() {
        XCTAssertThrowsError(try decode(#"{"cwd":"/w"}"#, .stop))
    }

    func testDecodeCapturesToolInput() throws {
        let json = """
        {"session_id":"s1","cwd":"/w","tool_name":"Edit",
         "tool_input":{"file_path":"a.ts","old_string":"x","new_string":"y"}}
        """
        let e = try HookEvent.decode(Data(json.utf8), name: .permissionRequest, now: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(e.toolName, "Edit")
        let dict = e.toolInputDict
        XCTAssertEqual(dict?["file_path"] as? String, "a.ts")
        XCTAssertEqual(dict?["new_string"] as? String, "y")
    }

    func testDecodeToolInputAbsentIsNil() throws {
        let e = try HookEvent.decode(Data(#"{"session_id":"s1"}"#.utf8), name: .stop, now: Date(timeIntervalSince1970: 100))
        XCTAssertNil(e.toolInput)
        XCTAssertNil(e.toolInputDict)
    }

    func testAgentIDDefaultsToClaudeWhenAbsent() throws {
        let e = try decode(#"{"session_id":"s1","cwd":"/w"}"#, .stop)
        XCTAssertEqual(e.agentID, "claude")
    }

    func testAgentIDDecodedFromPayload() throws {
        let e = try decode(#"{"session_id":"s1","cwd":"/w","agent_id":"codex"}"#, .stop)
        XCTAssertEqual(e.agentID, "codex")
    }

    func testPeekAgentIDReadsRawWithoutFullDecode() {
        XCTAssertEqual(HookEvent.peekAgentID(Data(#"{"agent_id":"codex","session_id":"s1"}"#.utf8)), "codex")
        XCTAssertEqual(HookEvent.peekAgentID(Data(#"{"session_id":"s1"}"#.utf8)), "claude")
        XCTAssertEqual(HookEvent.peekAgentID(Data("not json".utf8)), "claude")
    }
}
