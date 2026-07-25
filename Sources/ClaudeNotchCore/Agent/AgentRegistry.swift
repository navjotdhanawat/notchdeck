import Foundation

/// Resolves the `AgentProvider` for an event's `agent_id`. A missing/unknown id falls back to
/// the Claude provider, so pre-existing installs (no `agent_id`) and unknown future agents fail safe.
public final class AgentRegistry: Sendable {
    private let providers: [AgentProvider]
    private let fallback: AgentProvider

    public init(_ providers: [AgentProvider]) {
        precondition(providers.contains { $0.agentID == "claude" }, "registry must include a Claude provider")
        self.providers = providers
        self.fallback = providers.first { $0.agentID == "claude" }!
    }

    public static let `default` = AgentRegistry([
        ClaudeAgentProvider(),
        CodexAgentProvider(),
    ])

    public func provider(for id: String) -> AgentProvider {
        providers.first { $0.agentID == id } ?? fallback
    }

    /// Providers whose agent is installed on this machine — the set we install hooks for.
    public func presentProviders() -> [AgentProvider] {
        providers.filter { $0.isPresent() }
    }
}
