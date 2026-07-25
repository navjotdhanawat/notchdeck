import XCTest
@testable import NotchDeckCore

final class SessionStoreTests: XCTestCase {
    private var t = 0.0
    private func at() -> Date { t += 1; return Date(timeIntervalSince1970: t) }

    private func event(_ name: HookEventName, session: String = "s1",
                       matcher: String? = nil, tool: String? = nil,
                       iterm: String? = "w0t1p0:UUID-1") -> HookEvent {
        HookEvent(name: name, sessionID: session, cwd: "/w", matcher: matcher,
                  toolName: tool, transcriptPath: nil,
                  env: HookEnv(values: iterm.map { ["ITERM_SESSION_ID": $0] } ?? [:]), receivedAt: at())
    }

    private let provider: AgentProvider = ClaudeAgentProvider()

    func testSessionStartRegistersAsWorking() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart), provider: provider)
        let s = store.snapshot()
        XCTAssertEqual(s.count, 1)
        XCTAssertEqual(s[0].state, .working)
        XCTAssertEqual(s[0].terminal.adapterID, "iterm2")
        XCTAssertEqual(s[0].terminal.handle, "UUID-1")
        XCTAssertEqual(s[0].key, "iterm2:UUID-1")
    }

    func testPreToolUseSetsWorkingWithTool() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart), provider: provider)
        _ = store.apply(event(.preToolUse, tool: "Edit"), provider: provider)
        XCTAssertEqual(store.snapshot()[0].state, .working)
        XCTAssertEqual(store.snapshot()[0].currentTool, "Edit")
    }

    func testNotificationMatchersMapToStates() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart), provider: provider)
        _ = store.apply(event(.notification, matcher: "needs_input"), provider: provider)
        XCTAssertEqual(store.snapshot()[0].state, .needsInput)
        _ = store.apply(event(.notification, matcher: "permission_prompt"), provider: provider)
        XCTAssertEqual(store.snapshot()[0].state, .needsPermission)
    }

    func testPermissionRequestMapsToNeedsPermission() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart), provider: provider)
        _ = store.apply(event(.permissionRequest), provider: provider)
        XCTAssertEqual(store.snapshot()[0].state, .needsPermission)
    }

    func testStopEmitsDoneSoundAndState() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart), provider: provider)
        let fx = store.apply(event(.stop), provider: provider)
        XCTAssertEqual(store.snapshot()[0].state, .done)
        XCTAssertEqual(fx, [.soundDone])
    }

    func testStopFailureEmitsFailedSound() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart), provider: provider)
        let fx = store.apply(event(.stopFailure), provider: provider)
        XCTAssertEqual(store.snapshot()[0].state, .failed)
        XCTAssertEqual(fx, [.soundFailed])
    }

    func testEventWithoutSessionStartAutoRegisters() {
        let store = SessionStore()
        _ = store.apply(event(.stop), provider: provider)          // no prior SessionStart
        XCTAssertEqual(store.snapshot().count, 1)
        XCTAssertEqual(store.snapshot()[0].state, .done)
    }

    func testPurgeRemovesEndedAfterGraceAndStale() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart, session: "keep", iterm: "w0t0p0:K"), provider: provider)
        _ = store.apply(event(.sessionEnd, session: "gone", iterm: "w0t0p0:G"), provider: provider)
        // ended session older than grace, and no stale removal for the fresh one
        store.purge(now: Date(timeIntervalSince1970: t + 10), endedGrace: 5, staleTimeout: 3600)
        let keys = store.snapshot().map(\.key)
        XCTAssertEqual(keys, ["iterm2:K"])
    }

    func testSnapshotSortsAttentionFirst() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart, session: "a", iterm: "w0t0p0:A"), provider: provider) // working
        _ = store.apply(event(.notification, session: "b", matcher: "permission_prompt", iterm: "w0t0p0:B"), provider: provider)
        XCTAssertEqual(store.snapshot().first?.key, "iterm2:B") // needsPermission first
    }

    func testSessionCarriesAgentID() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart), provider: provider)
        XCTAssertEqual(store.snapshot()[0].agentID, "claude")
        XCTAssertEqual(store.snapshot()[0].agentSessionID, "s1")
    }
}
