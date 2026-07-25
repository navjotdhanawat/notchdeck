import XCTest
@testable import NotchDeckCore

final class CodexTests: XCTestCase {
    func testCodexRendersShellAndPatch() {
        let r = CodexToolRenderer()
        XCTAssertEqual(r.render(tool: "Bash", input: ["command": "ls -la"]), .command("ls -la"))
        // Codex puts both Bash and apply_patch content under tool_input.command (per hooks doc).
        if case .diff = r.render(tool: "apply_patch", input: ["command": "*** Update File: a.swift\n-old\n+new"]) {} else {
            XCTFail("apply_patch should render as a diff")
        }
        if case .raw = r.render(tool: "mystery_tool", input: [:]) {} else { XCTFail("unknown → raw") }
    }

    func testCodexActionLabels() {
        let r = CodexToolRenderer()
        XCTAssertEqual(r.actionLabel(toolName: "apply_patch", input: ["command": "*** Update File: /x/a.swift\n+z"]), "Edit a.swift")
        XCTAssertEqual(r.actionLabel(toolName: "Bash", input: ["command": "go build\n./run"]), "Bash: go build")
    }

    func testCodexDecisionMapperIsToolPermissionOnly() {
        let mapper = CodexDecisionMapper()
        let ti = try! JSONSerialization.data(withJSONObject: ["command": "rm -rf x"])
        let e = HookEvent(name: .permissionRequest, agentID: "codex", sessionID: "s1", cwd: "/w",
                          matcher: "*", toolName: "Bash", transcriptPath: nil, env: HookEnv(),
                          toolInput: ti, receivedAt: Date(timeIntervalSince1970: 1))
        guard case let .toolPermission(tool, _)? = mapper.request(from: e, id: "r", sessionKey: "k")?.kind else {
            return XCTFail("expected toolPermission")
        }
        XCTAssertEqual(tool, "Bash")
    }

    func testOpenAIPricingKnownAndUnknown() {
        XCTAssertNotNil(OpenAIPricing().cost(model: "gpt-5-codex", tokens: TokenUsage(input: 1_000_000)))
        XCTAssertNil(OpenAIPricing().cost(model: "claude-opus-4-8", tokens: TokenUsage(input: 1)))
    }

    func testCodexTranscriptParserSumsUsageAndModel() {
        // Verified Codex rollout schema: {type,payload,timestamp}; model in turn_context.payload.model;
        // usage in event_msg payload type "token_count" -> info.last_token_usage.
        let chunk = """
        {"type":"turn_context","payload":{"model":"gpt-5-codex"},"timestamp":"t"}
        {"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":20,"cache_write_input_tokens":0,"output_tokens":50,"reasoning_output_tokens":10,"total_tokens":150},"last_token_usage":{"input_tokens":100,"cached_input_tokens":20,"cache_write_input_tokens":0,"output_tokens":50,"reasoning_output_tokens":10,"total_tokens":150},"model_context_window":272000}},"timestamp":"t"}
        """
        let (model, usage) = CodexTranscriptParser().parse(chunk)
        XCTAssertEqual(model, "gpt-5-codex")
        // uncached input = 100 - 20 = 80; output_tokens = 50 (already includes 10 reasoning); cacheRead = 20.
        XCTAssertEqual(usage, TokenUsage(input: 80, output: 50, cacheCreation: 0, cacheRead: 20))
    }
}
