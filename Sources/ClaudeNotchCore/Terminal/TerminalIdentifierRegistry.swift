import Foundation

/// Priority-ordered set of terminal identifiers. `resolve` is total (the generic
/// identifier always matches last). New terminals register here — one line, no switch.
public final class TerminalIdentifierRegistry {
    private let identifiers: [TerminalIdentifying]

    public init(_ identifiers: [TerminalIdentifying]) {
        self.identifiers = identifiers.sorted { $0.priority > $1.priority }
    }

    public static let `default` = TerminalIdentifierRegistry([
        ITerm2Identifier(),
        WezTermIdentifier(),
        KittyIdentifier(),
        GenericTerminalIdentifier(),
    ])

    /// First identifier (by descending priority) that claims this env; generic backstop otherwise.
    public func resolve(_ env: HookEnv) -> TerminalIdentity {
        for identifier in identifiers {
            if let identity = identifier.identify(env) { return identity }
        }
        return TerminalIdentity(adapterID: "generic", handle: nil, appName: env.termProgram, pid: env.pid)
    }

    /// Stable session key: the terminal's handle when present, else the Claude session id.
    public func key(for env: HookEnv, sessionID: String) -> String {
        SessionKey.derive(identity: resolve(env), sessionID: sessionID)
    }

    /// De-duplicated union of every identifier's `requiredEnvKeys` — the bridge's forward allowlist.
    public var allEnvKeys: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for identifier in identifiers {
            for key in identifier.requiredEnvKeys where seen.insert(key).inserted {
                out.append(key)
            }
        }
        return out
    }
}
