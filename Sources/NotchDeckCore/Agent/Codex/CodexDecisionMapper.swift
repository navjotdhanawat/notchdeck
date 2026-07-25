import Foundation

/// Codex has no AskUserQuestion/ExitPlanMode tools, so every decision is a tool-permission card.
public struct CodexDecisionMapper: DecisionMapping {
    private let renderer: ToolRendering
    public init(renderer: ToolRendering = CodexToolRenderer()) { self.renderer = renderer }

    public func request(from event: HookEvent, id: String, sessionKey: String) -> DecisionRequest? {
        guard let tool = event.toolName else { return nil }
        let input = event.toolInputDict ?? [:]
        return DecisionRequest(id: id, sessionKey: sessionKey,
                               kind: .toolPermission(tool: tool, preview: renderer.render(tool: tool, input: input)),
                               receivedAt: event.receivedAt)
    }
}
