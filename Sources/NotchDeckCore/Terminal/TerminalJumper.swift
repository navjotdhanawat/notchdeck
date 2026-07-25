import Foundation

public enum JumpResult: Sendable, Equatable {
    case jumped
    case fellBack
    case failed(String)
}

/// One terminal's jump mechanic. `adapterID` matches the identifier that produced the identity.
public protocol TerminalJumping: Sendable {
    var adapterID: String { get }
    /// Attempt *precise* targeting only. `.jumped` on success; `.fellBack` if the adapter
    /// itself raised the app but couldn't target; `.failed` if it did nothing.
    func jump(to identity: TerminalIdentity) async -> JumpResult
}

/// Routes an identity to its adapter and owns the degrade chain: a precise `.failed`
/// falls through to the app-raise fallback. New terminals register in `adapters` — no switch.
public final class TerminalJumperRegistry {
    private let jumpers: [String: TerminalJumping]
    private let fallback: TerminalJumping

    public init(adapters: [TerminalJumping], fallback: TerminalJumping) {
        var map: [String: TerminalJumping] = [:]
        for a in adapters { map[a.adapterID] = a }
        self.jumpers = map
        self.fallback = fallback
    }

    public func jump(to identity: TerminalIdentity) async -> JumpResult {
        if let adapter = jumpers[identity.adapterID] {
            switch await adapter.jump(to: identity) {
            case .jumped:   return .jumped
            case .fellBack: return .fellBack     // adapter already raised the app
            case .failed:   break                // fall through to app-raise
            }
        }
        return await fallback.jump(to: identity)
    }
}
