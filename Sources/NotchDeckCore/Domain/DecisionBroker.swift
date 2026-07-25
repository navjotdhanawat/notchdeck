import Foundation

/// Holds in-flight decision requests. `decide` suspends until the UI calls `resolve`
/// or the timeout elapses (→ `.passthrough`, so the caller emits nothing and Claude
/// shows its normal prompt). `onPendingChanged` lets the UI mirror the pending list.
public actor DecisionBroker {
    private struct Waiter { let request: DecisionRequest; let continuation: CheckedContinuation<Decision, Never> }
    private var waiters: [String: Waiter] = [:]
    private let timeout: TimeInterval
    private var onPendingChanged: (@Sendable ([DecisionRequest]) -> Void)?

    public init(timeout: TimeInterval) { self.timeout = timeout }

    public func setOnPendingChanged(_ cb: @escaping @Sendable ([DecisionRequest]) -> Void) {
        onPendingChanged = cb
    }

    public func snapshotPending() -> [DecisionRequest] {
        waiters.values.map(\.request).sorted { $0.receivedAt < $1.receivedAt }
    }

    public func decide(_ request: DecisionRequest) async -> Decision {
        let id = request.id
        let t = timeout  // Capture timeout in actor context to avoid unnecessary await warning
        // Arm the timeout; if still pending when it fires, resolve to passthrough.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(t * 1_000_000_000))
            await self?.resolve(id: id, .passthrough)
        }
        return await withCheckedContinuation { cont in
            waiters[id] = Waiter(request: request, continuation: cont)
            notifyPending()
        }
    }

    public func resolve(id: String, _ decision: Decision) {
        guard let waiter = waiters.removeValue(forKey: id) else { return }
        waiter.continuation.resume(returning: decision)
        notifyPending()
    }

    private func notifyPending() {
        let snapshot = snapshotPending()
        onPendingChanged?(snapshot)
    }
}
