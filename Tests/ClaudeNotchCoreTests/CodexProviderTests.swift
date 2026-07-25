import XCTest
@testable import ClaudeNotchCore

final class CodexProviderTests: XCTestCase {
    private let codex = CodexAgentProvider()

    func testIdentityAndDefaults() {
        XCTAssertEqual(codex.agentID, "codex")
        // Shared encoder: Codex must produce the SAME decision JSON as Claude. Parse-and-compare
        // (order-independent) since DecisionEncoder does not sort keys.
        let c = (try? JSONSerialization.jsonObject(with: codex.decisionEncoder.stdoutJSON(for: .deny(reason: "x"))!)) as? NSDictionary
        let k = (try? JSONSerialization.jsonObject(with: ClaudeAgentProvider().decisionEncoder.stdoutJSON(for: .deny(reason: "x"))!)) as? NSDictionary
        XCTAssertEqual(c, k)
    }

    func testInstallProfileTargetsCodexHooksJSON() {
        let p = codex.installProfile
        XCTAssertTrue(p.settingsURL.path.hasSuffix(".codex/hooks.json"))
        XCTAssertNil(p.versionGate)   // never gated: old Codex ignores hooks.json entirely
        // Monitor hooks must be synchronous (Codex ignores `async`) with a short timeout.
        for spec in p.monitorSpecs {
            XCTAssertFalse(spec.isAsync, "\(spec.event) monitor hook must not be async for Codex")
            XCTAssertNotNil(spec.timeout)
        }
        // Each command carries the codex agent tag.
        XCTAssertTrue(p.monitorSpecs.allSatisfy { $0.args.hasPrefix("--agent codex ") })
        XCTAssertTrue(p.decisionSpecs.allSatisfy { $0.args.contains("--agent codex decide ") })
        XCTAssertTrue(p.decisionSpecs.allSatisfy { $0.event == "PermissionRequest" },
                      "Codex decide hooks must be PermissionRequest-only (PreToolUse decide would block every tool)")
    }

    func testInstallWritesCodexHooksToTempFile() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("codex-hooks-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url)
                try? FileManager.default.removeItem(at: url.deletingLastPathComponent().appendingPathComponent("hooks.json.claudenotch-backup")) }
        let p = codex.installProfile
        try HookInstaller(helperPath: "/App/notch-bridge",
                          specs: p.monitorSpecs + p.decisionSpecs,
                          backupFilename: p.backupFilename).install(into: url)
        let hooks = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        XCTAssertNotNil((hooks["hooks"] as! [String: Any])["PreToolUse"])
        XCTAssertNotNil((hooks["hooks"] as! [String: Any])["SessionStart"])
    }

    func testRegistryDefaultNowIncludesCodex() {
        XCTAssertEqual(AgentRegistry.default.provider(for: "codex").agentID, "codex")
    }
}
