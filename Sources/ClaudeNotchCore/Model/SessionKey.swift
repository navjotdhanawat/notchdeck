import Foundation

/// Single source of truth for a session's stable key: the terminal's handle when
/// present, else the Claude session id. Shared by SessionStore and the decision path.
public enum SessionKey {
    public static func derive(identity: TerminalIdentity, sessionID: String) -> String {
        if let h = identity.handle, !h.isEmpty { return "\(identity.adapterID):\(h)" }
        return sessionID
    }
}
