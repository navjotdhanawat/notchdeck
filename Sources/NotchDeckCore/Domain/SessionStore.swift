import Foundation

public enum SessionEffect: Sendable, Equatable { case soundDone, soundFailed }

public final class SessionStore {
    private var sessions: [String: Session] = [:]
    private let identifiers: TerminalIdentifierRegistry
    public init(identifiers: TerminalIdentifierRegistry = .default) { self.identifiers = identifiers }

    private func title(fromCwd cwd: String) -> String? {
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty ? nil : name
    }

    @discardableResult
    public func apply(_ event: HookEvent, provider: AgentProvider) -> [SessionEffect] {
        let identity = identifiers.resolve(event.env)
        let k = SessionKey.derive(identity: identity, sessionID: event.sessionID)
        var s = sessions[k] ?? Session(
            key: k, agentID: provider.agentID, agentSessionID: event.sessionID, terminal: identity,
            cwd: event.cwd, title: title(fromCwd: event.cwd),
            state: .working, currentTool: nil, currentAction: nil,
            stateSince: event.receivedAt, usage: nil,
            startedAt: event.receivedAt, lastEventAt: event.receivedAt
        )
        s.lastEventAt = event.receivedAt
        if s.cwd.isEmpty { s.cwd = event.cwd }
        // Terminal identity is fixed at creation. Sessions with a terminal handle are keyed
        // "adapterID:handle" (adapter-namespaced so equal handles from different terminals —
        // e.g. WezTerm pane 1 vs Kitty window 1 — never collide); handle-less sessions are
        // keyed by the Claude session id. An in-place terminal change under one key can't occur.
        let previousState = s.state
        var effects: [SessionEffect] = []

        switch event.name {
        case .sessionStart:
            s.state = .working
        case .preToolUse:
            s.state = .working
            if let tool = event.toolName { s.currentTool = tool }
            s.currentAction = provider.toolRenderer.actionLabel(toolName: event.toolName, input: event.toolInputDict)
        case .notification:
            switch event.matcher {
            case "permission_prompt": s.state = .needsPermission
            // Real asks (elicitation_dialog / agent_needs_input) arrive collapsed as "needs_input".
            // idle_prompt is not monitored, so an idle-at-prompt session keeps its prior state (e.g. .done).
            case "needs_input": s.state = .needsInput
            default: break // informational / idle notifications don't change state
            }
        case .permissionRequest:
            s.state = .needsPermission
        case .stop:
            s.state = .done
            effects.append(.soundDone)
        case .stopFailure:
            s.state = .failed
            effects.append(.soundFailed)
        case .sessionEnd:
            s.state = .ended
        }

        if s.state != previousState { s.stateSince = event.receivedAt }

        sessions[k] = s
        return effects
    }

    /// Merge fresh transcript-derived usage onto a session without altering its state.
    public func updateUsage(sessionKey: String, _ usage: SessionUsage) {
        guard var s = sessions[sessionKey] else { return }
        s.usage = usage
        sessions[sessionKey] = s
    }

    /// Look up a session by its derived key — used to jump to the terminal from a decision request.
    public func session(forKey key: String) -> Session? {
        sessions[key]
    }

    public func purge(now: Date, endedGrace: TimeInterval, staleTimeout: TimeInterval) {
        sessions = sessions.filter { _, s in
            if s.state == .ended { return now.timeIntervalSince(s.lastEventAt) < endedGrace }
            return now.timeIntervalSince(s.lastEventAt) < staleTimeout
        }
    }

    public func snapshot() -> [Session] {
        func rank(_ st: SessionState) -> Int {
            switch st {
            case .needsPermission: return 0
            case .needsInput: return 1
            case .working: return 2
            case .failed: return 3
            case .done: return 4
            case .ended: return 5
            }
        }
        return sessions.values.sorted {
            rank($0.state) != rank($1.state) ? rank($0.state) < rank($1.state)
                                             : $0.startedAt < $1.startedAt
        }
    }
}
