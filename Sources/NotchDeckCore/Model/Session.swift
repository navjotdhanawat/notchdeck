import Foundation

public enum SessionState: Sendable, Equatable {
    case working, needsInput, needsPermission, done, failed, ended
}

public struct Session: Identifiable, Sendable, Equatable {
    public var id: String { key }
    public let key: String
    public var agentID: String
    public var agentSessionID: String
    public var terminal: TerminalIdentity
    public var cwd: String
    public var title: String?
    public var state: SessionState
    public var currentTool: String?
    public var currentAction: String?      // human-readable, e.g. "Edit AppCoordinator.swift"
    public var stateSince: Date            // when `state` was last entered → time-in-state
    public var usage: SessionUsage?        // model + tokens + cost (nil until first transcript scan)
    public var startedAt: Date
    public var lastEventAt: Date

    /// Display name: the cwd's last path component, else the terminal name, else "session".
    public var projectName: String {
        let base = (cwd as NSString).lastPathComponent
        if !base.isEmpty, base != "/" { return base }
        if let app = terminal.appName, !app.isEmpty {
            return app.replacingOccurrences(of: ".app", with: "")
        }
        return "session"
    }
}
