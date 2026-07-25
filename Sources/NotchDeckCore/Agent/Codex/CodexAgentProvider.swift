import Foundation

/// The Codex CLI agent. Its hook contract mirrors Claude's (same event names, stdin fields,
/// and hookSpecificOutput decision envelope), so it reuses the shared decode + decision encoder
/// and differs only in install location, tool catalog, transcript schema, and pricing.
public struct CodexAgentProvider: AgentProvider {
    public init() {}
    public let agentID = "codex"
    public let displayName = "Codex CLI"

    /// Present when the user has a ~/.codex directory (Codex creates it on first run).
    public func isPresent() -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: CodexPaths.codexDir.path, isDirectory: &isDir) && isDir.boolValue
    }

    public var installProfile: AgentInstallProfile {
        // Codex ignores `async` (unsupported) → monitor hooks are synchronous with a short timeout;
        // the bridge POSTs-and-returns fast, so the CLI never stalls.
        AgentInstallProfile(
            settingsURL: CodexPaths.hooksURL,
            backupFilename: "hooks.json.claudenotch-backup",
            monitorSpecs: [
                HookSpec(event: "SessionStart", matcher: "*", args: "--agent codex SessionStart", isAsync: false, timeout: 5),
                HookSpec(event: "PreToolUse", matcher: "*", args: "--agent codex PreToolUse", isAsync: false, timeout: 5),
                HookSpec(event: "Stop", matcher: "*", args: "--agent codex Stop", isAsync: false, timeout: 5),
                HookSpec(event: "SessionEnd", matcher: "*", args: "--agent codex SessionEnd", isAsync: false, timeout: 3),
            ],
            decisionSpecs: [
                // Act-in-place goes through PermissionRequest (fires only when Codex wants approval),
                // NOT PreToolUse (which fires for EVERY tool call and would block them all).
                HookSpec(event: "PermissionRequest", matcher: "*",
                         args: "--agent codex decide PermissionRequest", isAsync: false, timeout: 600),
            ],
            versionGate: nil   // never gate: an old Codex without hook support ignores hooks.json entirely.
        )
    }

    public var decisionMapper: DecisionMapping { CodexDecisionMapper(renderer: toolRenderer) }
    public var transcriptParser: TranscriptParsing { CodexTranscriptParser() }
    public var costEstimator: CostEstimator { OpenAIPricing() }
    public var toolRenderer: ToolRendering { CodexToolRenderer() }
    // eventMapper + decisionEncoder come from the shared AgentProvider defaults.
}
