import Foundation

/// Generic, terminal-agnostic identity for a session's terminal. Replaces the closed
/// `TerminalRef` enum: adding a terminal never adds a case here.
public struct TerminalIdentity: Sendable, Equatable {
    /// Matches the owning adapter's `adapterID` on both the identifier and the jumper.
    public let adapterID: String
    /// Stable per-pane/window handle for precise jump; nil when the terminal exposes none.
    public let handle: String?
    /// App name (e.g. "iTerm.app", "WezTerm") for app-raise fallback + display.
    public let appName: String?
    public let pid: Int?

    public init(adapterID: String, handle: String? = nil, appName: String? = nil, pid: Int? = nil) {
        self.adapterID = adapterID
        self.handle = handle
        self.appName = appName
        self.pid = pid
    }
}
