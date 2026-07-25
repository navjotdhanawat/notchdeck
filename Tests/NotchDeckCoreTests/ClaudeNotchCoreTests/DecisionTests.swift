import XCTest
@testable import NotchDeckCore

final class DecisionTests: XCTestCase {
    private let mapper = ClaudeDecisionMapper()

    private func event(tool: String, input: [String: Any]) -> HookEvent {
        let data = try! JSONSerialization.data(withJSONObject: input)
        return HookEvent(name: .permissionRequest, sessionID: "s1", cwd: "/w", matcher: "*",
                         toolName: tool, transcriptPath: nil,
                         env: HookEnv(values: ["ITERM_SESSION_ID": "w0t1p0:UUID-1"]), toolInput: data,
                         receivedAt: Date(timeIntervalSince1970: 5))
    }

    func testFromEditIsToolPermission() {
        let req = mapper.request(from: event(tool: "Edit",
            input: ["file_path": "a.ts", "old_string": "x", "new_string": "y"]),
            id: "r1", sessionKey: "iterm2:UUID-1")
        XCTAssertEqual(req?.sessionKey, "iterm2:UUID-1")
        guard case let .toolPermission(tool, preview)? = req?.kind else { return XCTFail() }
        XCTAssertEqual(tool, "Edit")
        guard case .diff = preview else { return XCTFail("expected diff preview") }
    }

    func testFromExitPlanModeIsPlanApproval() {
        let req = mapper.request(from: event(tool: "ExitPlanMode", input: ["plan": "1. do X\n2. do Y"]),
                                 id: "r2", sessionKey: "k")
        guard case let .planApproval(text)? = req?.kind else { return XCTFail() }
        XCTAssertEqual(text, "1. do X\n2. do Y")
    }

    func testFromAskUserQuestionIsQuestion() {
        let input: [String: Any] = ["questions": [["question": "Pick?", "header": "H", "multiSelect": false,
            "options": [["label": "A", "description": "aa"], ["label": "B", "description": nil as Any? as Any]]]]]
        let req = mapper.request(from: event(tool: "AskUserQuestion", input: input), id: "r4", sessionKey: "k")
        guard case let .question(qs)? = req?.kind else { return XCTFail() }
        XCTAssertEqual(qs.first?.question, "Pick?")
        XCTAssertEqual(qs.first?.options.first?.label, "A")
    }

    func testFromWithoutToolNameIsNil() {
        let e = HookEvent(name: .permissionRequest, sessionID: "s1", cwd: "/w", matcher: nil,
                          toolName: nil, transcriptPath: nil, env: HookEnv(), toolInput: nil,
                          receivedAt: Date(timeIntervalSince1970: 5))
        XCTAssertNil(mapper.request(from: e, id: "r3", sessionKey: "k"))
    }
}
