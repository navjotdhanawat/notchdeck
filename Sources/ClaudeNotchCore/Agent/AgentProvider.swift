import Foundation

/// One AI agent's pluggable integration: how to install its hooks, decode its events,
/// map/encode decisions, parse its transcript, price it, and render its tools. Adding an
/// agent = one conformer + one line in `AgentRegistry.default`.
public protocol AgentProvider: Sendable {
    var agentID: String { get }
    var displayName: String { get }
    /// Whether this agent is installed on this machine (drives which agents we install hooks for).
    func isPresent() -> Bool
    var installProfile: AgentInstallProfile { get }
    var eventMapper: HookEventMapping { get }
    var decisionMapper: DecisionMapping { get }
    var decisionEncoder: DecisionEncoding { get }
    var transcriptParser: TranscriptParsing { get }
    var costEstimator: CostEstimator { get }
    var toolRenderer: ToolRendering { get }
}

public extension AgentProvider {
    // Shared defaults: Claude and Codex have byte-identical inbound field names and decision JSON.
    var eventMapper: HookEventMapping { DefaultHookEventMapper() }
    var decisionEncoder: DecisionEncoding { HookSpecificOutputEncoder() }
}
