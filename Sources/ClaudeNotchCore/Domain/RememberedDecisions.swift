import Foundation

/// In-memory "allow for this session" store, scoped per (sessionKey, tool).
/// Never persisted to disk. Thread-safe (accessed from the decision path off the main actor).
public final class RememberedDecisions: @unchecked Sendable {
    private var allowed: Set<String> = []
    private let lock = NSLock()

    public init() {}

    private func k(_ sessionKey: String, _ tool: String) -> String { "\(sessionKey)\u{0}\(tool)" }

    public func remember(sessionKey: String, tool: String) {
        lock.lock(); defer { lock.unlock() }
        allowed.insert(k(sessionKey, tool))
    }

    public func isAllowed(sessionKey: String, tool: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return allowed.contains(k(sessionKey, tool))
    }

    public func clear(sessionKey: String) {
        lock.lock(); defer { lock.unlock() }
        allowed = allowed.filter { !$0.hasPrefix("\(sessionKey)\u{0}") }
    }

    public func clearAll() {
        lock.lock(); defer { lock.unlock() }
        allowed.removeAll()
    }
}
