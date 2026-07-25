import Foundation

/// One terminal's pure rule for turning hook env vars into a `TerminalIdentity`.
public protocol TerminalIdentifying: Sendable {
    /// Stable id shared with the matching jumper.
    var adapterID: String { get }
    /// Higher wins when more than one identifier matches; the generic catch-all is lowest.
    var priority: Int { get }
    /// Env var names this identifier reads — the union forms the bridge's forward allowlist.
    var requiredEnvKeys: [String] { get }
    /// Returns an identity if this env belongs to this terminal, else nil.
    func identify(_ env: HookEnv) -> TerminalIdentity?
}

public struct ITerm2Identifier: TerminalIdentifying {
    public init() {}
    public let adapterID = "iterm2"
    public let priority = 100
    public let requiredEnvKeys = ["ITERM_SESSION_ID", "TERM_PROGRAM"]
    public func identify(_ env: HookEnv) -> TerminalIdentity? {
        guard let raw = env.values["ITERM_SESSION_ID"], !raw.isEmpty else { return nil }
        return TerminalIdentity(adapterID: adapterID, handle: Self.uuid(from: raw),
                                appName: env.termProgram, pid: env.pid)
    }
    /// `ITERM_SESSION_ID` looks like `w0t1p0:UUID`; the AppleScript session id is the UUID suffix.
    static func uuid(from raw: String) -> String {
        if let colon = raw.lastIndex(of: ":") { return String(raw[raw.index(after: colon)...]) }
        return raw
    }
}

public struct WezTermIdentifier: TerminalIdentifying {
    public init() {}
    public let adapterID = "wezterm"
    public let priority = 90
    public let requiredEnvKeys = ["WEZTERM_PANE", "TERM_PROGRAM"]
    public func identify(_ env: HookEnv) -> TerminalIdentity? {
        guard let pane = env.values["WEZTERM_PANE"], !pane.isEmpty else { return nil }
        return TerminalIdentity(adapterID: adapterID, handle: pane,
                                appName: env.termProgram ?? "WezTerm", pid: env.pid)
    }
}

public struct KittyIdentifier: TerminalIdentifying {
    public init() {}
    public let adapterID = "kitty"
    public let priority = 90
    public let requiredEnvKeys = ["KITTY_WINDOW_ID", "TERM_PROGRAM"]
    public func identify(_ env: HookEnv) -> TerminalIdentity? {
        guard let win = env.values["KITTY_WINDOW_ID"], !win.isEmpty else { return nil }
        return TerminalIdentity(adapterID: adapterID, handle: win,
                                appName: env.termProgram ?? "kitty", pid: env.pid)
    }
}

/// Always matches (lowest priority). Produces a handle-less identity → app-raise fallback.
public struct GenericTerminalIdentifier: TerminalIdentifying {
    public init() {}
    public let adapterID = "generic"
    public let priority = 0
    public let requiredEnvKeys = ["TERM_PROGRAM"]
    public func identify(_ env: HookEnv) -> TerminalIdentity? {
        TerminalIdentity(adapterID: adapterID, handle: nil, appName: env.termProgram, pid: env.pid)
    }
}
