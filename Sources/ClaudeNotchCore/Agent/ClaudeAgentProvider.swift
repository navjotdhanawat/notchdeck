import Foundation

/// The Claude Code agent, extracted from the pre-seam code. Behavior is byte-identical to
/// what ClaudeNotch shipped before multi-agent support.
public struct ClaudeAgentProvider: AgentProvider {
    public init() {}
    public let agentID = "claude"
    public let displayName = "Claude Code"

    // Claude is the primary target; ClaudeNotch has always installed its hooks unconditionally.
    public func isPresent() -> Bool { true }

    public var installProfile: AgentInstallProfile {
        AgentInstallProfile(
            settingsURL: Paths.claudeSettingsURL,
            backupFilename: "settings.json.claudenotch-backup",
            monitorSpecs: [
                HookSpec(event: "SessionStart", matcher: "*", args: "--agent claude SessionStart", isAsync: true, timeout: nil),
                HookSpec(event: "PreToolUse", matcher: "*", args: "--agent claude PreToolUse", isAsync: true, timeout: nil),
                HookSpec(event: "Notification", matcher: "permission_prompt",
                         args: "--agent claude Notification permission_prompt", isAsync: true, timeout: nil),
                // idle_prompt is intentionally NOT monitored — it fires when a session is merely
                // idle at its prompt (finished a turn), not when Claude actually needs input.
                // Monitoring it made idle/done sessions show a false "waiting" state.
                HookSpec(event: "Notification", matcher: "elicitation_dialog|agent_needs_input",
                         args: "--agent claude Notification needs_input", isAsync: true, timeout: nil),
                HookSpec(event: "Stop", matcher: "*", args: "--agent claude Stop", isAsync: true, timeout: nil),
                HookSpec(event: "StopFailure", matcher: "*", args: "--agent claude StopFailure", isAsync: true, timeout: nil),
                HookSpec(event: "SessionEnd", matcher: "*", args: "--agent claude SessionEnd", isAsync: true, timeout: nil),
            ],
            decisionSpecs: [
                HookSpec(event: "PermissionRequest", matcher: "*",
                         args: "--agent claude decide PermissionRequest", isAsync: false, timeout: 600),
                HookSpec(event: "PermissionRequest", matcher: "ExitPlanMode",
                         args: "--agent claude decide PermissionRequest", isAsync: false, timeout: 600),
                HookSpec(event: "PreToolUse", matcher: "AskUserQuestion",
                         args: "--agent claude decide PreToolUse", isAsync: false, timeout: 600),
            ],
            versionGate: VersionGate(binary: "claude", minVersion: (2, 1, 200))
        )
    }

    public var decisionMapper: DecisionMapping { ClaudeDecisionMapper(renderer: toolRenderer) }
    public var transcriptParser: TranscriptParsing { ClaudeTranscriptParser() }
    public var costEstimator: CostEstimator { ClaudePricing() }
    public var toolRenderer: ToolRendering { ClaudeToolRenderer() }
    // eventMapper + decisionEncoder come from the shared defaults in the AgentProvider extension.
}
