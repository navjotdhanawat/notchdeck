# ClaudeNotch v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS notch app that shows the live state of parallel Claude Code sessions and click-jumps to the exact iTerm2 pane.

**Architecture:** Claude Code hooks invoke a tiny bundled helper (`notch-bridge`) that captures `ITERM_SESSION_ID` from its environment and POSTs each event to a localhost HTTP server inside the Swift app. A pure `SessionStore` state machine turns events into per-session state; `NotchController` (DynamicNotchKit) renders it; clicking a session runs `ITerm2Jumper` (AppleScript). All logic lives in a dependency-free `ClaudeNotchCore` library (unit-tested); I/O, UI, and AppleScript glue live in the app target (build + manual verification). See spec: `docs/superpowers/specs/2026-07-22-claudenotch-design.md`.

**Tech Stack:** Swift 6 (SwiftPM), AppKit + SwiftUI, Network.framework, AVFoundation, AppleScript (NSAppleScript), DynamicNotchKit (only external dependency).

## Global Constraints

- **Platform:** macOS 14+, Apple Silicon. App runs as `.accessory` (no Dock icon) via `NSApp.setActivationPolicy(.accessory)`. Unsandboxed.
- **Toolchain:** `swift-tools-version: 6.0`. Package uses `swiftLanguageModes: [.v5]` to avoid strict-concurrency friction in v1 (if that Package API is unavailable, use per-target `swiftSettings: [.swiftLanguageMode(.v5)]`).
- **Dependencies:** DynamicNotchKit (MIT) via SPM is the ONLY external dependency. `ClaudeNotchCore` has zero dependencies.
- **Repo:** Local git only — never add a remote or push. **No JIRA.** Commit messages: Conventional Commits type, NO ticket prefix. Every commit message ends with the trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` (shown in each commit step).
- **Hook path must never degrade Claude Code:** all hooks are registered `async: true` (fire-and-forget); the helper has a short timeout and always exits 0; every failure is a silent no-op.
- **settings.json safety:** writes are atomic (temp file + rename), take a timestamped backup, are marker-scoped (only our entries), and preserve all pre-existing user hooks.
- **Security:** HTTP server binds `127.0.0.1` only; every request must carry header `X-ClaudeNotch-Token` matching the per-launch token, else 401. No external network, no telemetry, no accounts. v1 handles metadata only (never reads transcript content). `bridge.json` is written mode `0600`.
- **Testing scope:** exactly spec §13 — unit-test the pure seams in `ClaudeNotchCore` (`HookEvent`, `SessionStore`, `TerminalJumperRegistry`, `BridgeConfig`, `HookInstaller`); verify I/O/UI/AppleScript by build + manual smoke. Do NOT add speculative tests beyond this.

## File Structure

```
claude-notch/
  Package.swift
  Sources/
    ClaudeNotchCore/                 # pure, zero-dependency, unit-tested
      Model/Session.swift            # Session, SessionState, TerminalRef
      Model/HookEvent.swift          # HookEventName, HookEnv, HookEvent(+decode)
      Domain/SessionStore.swift      # apply/purge/snapshot + SessionEffect
      Terminal/TerminalJumper.swift  # TerminalJumper protocol, JumpResult, TerminalJumperRegistry
      Config/Paths.swift             # app-support / bridge.json / settings.json locations
      Config/BridgeConfig.swift      # BridgeConfig + BridgeConfigWriter
      Install/HookInstaller.swift    # settings.json merge / uninstall / status
    ClaudeNotchApp/                  # I/O, UI, AppleScript glue; build + manual
      Transport/HookServer.swift     # NWListener + minimal HTTP + token auth
      Terminal/ITerm2Jumper.swift    # AppleScript precise jump
      Terminal/FallbackActivator.swift
      Sound/SoundPlayer.swift
      UI/NotchController.swift
      UI/NotchViews.swift
      AppCoordinator.swift
      main.swift
    notch-bridge/
      main.swift                     # tiny helper: stdin+env -> POST
  Tests/
    ClaudeNotchCoreTests/
      HookEventTests.swift
      SessionStoreTests.swift
      TerminalJumperRegistryTests.swift
      BridgeConfigTests.swift
      HookInstallerTests.swift
```

---

### Task 1: Package skeleton + DynamicNotchKit + green test harness

**Files:**
- Create: `Package.swift`
- Create: `Sources/ClaudeNotchCore/Model/Placeholder.swift` (temporary, removed in Task 2)
- Create: `Sources/ClaudeNotchApp/main.swift` (stub)
- Create: `Sources/notch-bridge/main.swift` (stub)
- Create: `Tests/ClaudeNotchCoreTests/SmokeTests.swift`

**Interfaces:**
- Produces: three targets (`ClaudeNotchCore` library, `ClaudeNotchApp` executable, `notch-bridge` executable) + `ClaudeNotchCoreTests`. Confirms `swift build` and `swift test` work end-to-end.

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeNotch",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/MrKai77/DynamicNotchKit.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "ClaudeNotchCore"),
        .executableTarget(
            name: "ClaudeNotchApp",
            dependencies: [
                "ClaudeNotchCore",
                .product(name: "DynamicNotchKit", package: "DynamicNotchKit")
            ]
        ),
        .executableTarget(name: "notch-bridge", dependencies: ["ClaudeNotchCore"]),
        .testTarget(name: "ClaudeNotchCoreTests", dependencies: ["ClaudeNotchCore"])
    ],
    swiftLanguageModes: [.v5]
)
```

- [ ] **Step 2: Create stub sources**

`Sources/ClaudeNotchCore/Model/Placeholder.swift`:
```swift
public enum ClaudeNotchCore { public static let version = "0.1.0" }
```

`Sources/ClaudeNotchApp/main.swift`:
```swift
import ClaudeNotchCore
print("ClaudeNotchApp \(ClaudeNotchCore.version)")
```

`Sources/notch-bridge/main.swift`:
```swift
import ClaudeNotchCore
print("notch-bridge \(ClaudeNotchCore.version)")
```

- [ ] **Step 3: Write the smoke test**

`Tests/ClaudeNotchCoreTests/SmokeTests.swift`:
```swift
import XCTest
@testable import ClaudeNotchCore

final class SmokeTests: XCTestCase {
    func testVersionExists() {
        XCTAssertEqual(ClaudeNotchCore.version, "0.1.0")
    }
}
```

- [ ] **Step 4: Resolve + build + test**

Run: `swift build`
Expected: builds all targets (DynamicNotchKit resolves). If the DynamicNotchKit `from:` version fails to resolve, run `swift package resolve` and pin to the latest tag it reports, then update `Package.swift`.

Run: `swift test`
Expected: `testVersionExists` PASSES.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: SPM skeleton with core/app/helper targets and green test harness" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: HookEvent model + resilient decoding

**Files:**
- Create: `Sources/ClaudeNotchCore/Model/HookEvent.swift`
- Delete: `Sources/ClaudeNotchCore/Model/Placeholder.swift` (move `version` into HookEvent.swift or keep a tiny Core.swift — see step)
- Create: `Tests/ClaudeNotchCoreTests/HookEventTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum HookEventName: String { sessionStart="SessionStart", preToolUse="PreToolUse", notification="Notification", stop="Stop", stopFailure="StopFailure", sessionEnd="SessionEnd", permissionRequest="PermissionRequest" }`
  - `struct HookEnv { var itermSessionID: String?; var termProgram: String?; var pid: Int? }`
  - `struct HookEvent { let name: HookEventName; let sessionID: String; let cwd: String; let matcher: String?; let toolName: String?; let transcriptPath: String?; let env: HookEnv; let receivedAt: Date }`
  - `static func HookEvent.decode(_ data: Data, name: HookEventName, now: Date) throws -> HookEvent`
  - `enum HookDecodeError: Error { case notAnObject, missingSessionID }`

- [ ] **Step 1: Write the failing tests**

`Tests/ClaudeNotchCoreTests/HookEventTests.swift`:
```swift
import XCTest
@testable import ClaudeNotchCore

final class HookEventTests: XCTestCase {
    private func decode(_ json: String, _ name: HookEventName) throws -> HookEvent {
        try HookEvent.decode(Data(json.utf8), name: name, now: Date(timeIntervalSince1970: 100))
    }

    func testDecodesCoreFieldsAndIgnoresUnknown() throws {
        let e = try decode(#"""
        {"session_id":"abc","cwd":"/w/proj","tool_name":"Bash",
         "transcript_path":"/t.jsonl","some_future_field":42,
         "env":{"ITERM_SESSION_ID":"w0t1p0:UUID-1","TERM_PROGRAM":"iTerm.app","PID":"123"}}
        """#, .preToolUse)
        XCTAssertEqual(e.name, .preToolUse)
        XCTAssertEqual(e.sessionID, "abc")
        XCTAssertEqual(e.cwd, "/w/proj")
        XCTAssertEqual(e.toolName, "Bash")
        XCTAssertEqual(e.transcriptPath, "/t.jsonl")
        XCTAssertEqual(e.env.itermSessionID, "w0t1p0:UUID-1")
        XCTAssertEqual(e.env.termProgram, "iTerm.app")
        XCTAssertEqual(e.env.pid, 123)
    }

    func testMatcherAndMissingEnvTolerated() throws {
        let e = try decode(#"{"session_id":"x","cwd":"/w","matcher":"permission_prompt"}"#, .notification)
        XCTAssertEqual(e.matcher, "permission_prompt")
        XCTAssertNil(e.env.itermSessionID)
        XCTAssertNil(e.toolName)
    }

    func testMissingSessionIDThrows() {
        XCTAssertThrowsError(try decode(#"{"cwd":"/w"}"#, .stop))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter HookEventTests`
Expected: FAIL — `HookEvent` / `HookEventName` not defined.

- [ ] **Step 3: Implement `HookEvent.swift`**

```swift
import Foundation

public enum ClaudeNotchCore { public static let version = "0.1.0" }

public enum HookEventName: String, Sendable {
    case sessionStart = "SessionStart"
    case preToolUse = "PreToolUse"
    case notification = "Notification"
    case stop = "Stop"
    case stopFailure = "StopFailure"
    case sessionEnd = "SessionEnd"
    case permissionRequest = "PermissionRequest"
}

public struct HookEnv: Sendable, Equatable {
    public var itermSessionID: String?
    public var termProgram: String?
    public var pid: Int?
    public init(itermSessionID: String? = nil, termProgram: String? = nil, pid: Int? = nil) {
        self.itermSessionID = itermSessionID
        self.termProgram = termProgram
        self.pid = pid
    }
}

public enum HookDecodeError: Error { case notAnObject, missingSessionID }

public struct HookEvent: Sendable, Equatable {
    public let name: HookEventName
    public let sessionID: String
    public let cwd: String
    public let matcher: String?
    public let toolName: String?
    public let transcriptPath: String?
    public let env: HookEnv
    public let receivedAt: Date

    public init(name: HookEventName, sessionID: String, cwd: String, matcher: String?,
                toolName: String?, transcriptPath: String?, env: HookEnv, receivedAt: Date) {
        self.name = name; self.sessionID = sessionID; self.cwd = cwd; self.matcher = matcher
        self.toolName = toolName; self.transcriptPath = transcriptPath; self.env = env
        self.receivedAt = receivedAt
    }

    /// Resilient decode via JSONSerialization so unknown/extra Claude Code fields never break us.
    public static func decode(_ data: Data, name: HookEventName, now: Date) throws -> HookEvent {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HookDecodeError.notAnObject
        }
        guard let sessionID = obj["session_id"] as? String, !sessionID.isEmpty else {
            throw HookDecodeError.missingSessionID
        }
        var env = HookEnv()
        if let e = obj["env"] as? [String: Any] {
            env.itermSessionID = e["ITERM_SESSION_ID"] as? String
            env.termProgram = e["TERM_PROGRAM"] as? String
            if let p = e["PID"] as? String { env.pid = Int(p) } else if let p = e["PID"] as? Int { env.pid = p }
        }
        return HookEvent(
            name: name,
            sessionID: sessionID,
            cwd: (obj["cwd"] as? String) ?? "",
            matcher: obj["matcher"] as? String,
            toolName: obj["tool_name"] as? String,
            transcriptPath: obj["transcript_path"] as? String,
            env: env,
            receivedAt: now
        )
    }
}
```
Then delete `Sources/ClaudeNotchCore/Model/Placeholder.swift` (its `version` now lives here).

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter HookEventTests`
Expected: all 3 PASS.
Run: `swift test` — SmokeTests still PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: HookEvent value type with resilient JSON decoding" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Session model + SessionStore state machine

**Files:**
- Create: `Sources/ClaudeNotchCore/Model/Session.swift`
- Create: `Sources/ClaudeNotchCore/Domain/SessionStore.swift`
- Create: `Tests/ClaudeNotchCoreTests/SessionStoreTests.swift`

**Interfaces:**
- Consumes: `HookEvent`, `HookEventName`, `HookEnv` (Task 2).
- Produces:
  - `enum SessionState: Sendable { working, needsInput, needsPermission, done, failed, ended }`
  - `enum TerminalRef: Sendable, Equatable { case iterm(uuid: String); case other(termProgram: String?, pid: Int?) }` with `static func from(_ env: HookEnv) -> TerminalRef` and `static func itermUUID(from raw: String) -> String` (strips `wNtNpN:` prefix)
  - `struct Session: Identifiable, Sendable, Equatable { var id: String {key}; let key; var claudeSessionID; var terminal; var cwd; var title; var model; var state; var currentTool; var startedAt; var lastEventAt }`
  - `enum SessionEffect: Sendable, Equatable { soundDone, soundFailed }`
  - `final class SessionStore { func apply(_ event: HookEvent) -> [SessionEffect]; func purge(now: Date, endedGrace: TimeInterval, staleTimeout: TimeInterval); func snapshot() -> [Session] }`
  - Key rule: stable `key` = iTerm UUID suffix if present, else `session_id`. `snapshot()` sorts by attention priority (needsPermission, needsInput first) then `startedAt`.

- [ ] **Step 1: Write the failing tests**

`Tests/ClaudeNotchCoreTests/SessionStoreTests.swift`:
```swift
import XCTest
@testable import ClaudeNotchCore

final class SessionStoreTests: XCTestCase {
    private var t = 0.0
    private func at() -> Date { t += 1; return Date(timeIntervalSince1970: t) }

    private func event(_ name: HookEventName, session: String = "s1",
                       matcher: String? = nil, tool: String? = nil,
                       iterm: String? = "w0t1p0:UUID-1") -> HookEvent {
        HookEvent(name: name, sessionID: session, cwd: "/w", matcher: matcher,
                  toolName: tool, transcriptPath: nil,
                  env: HookEnv(itermSessionID: iterm), receivedAt: at())
    }

    func testItermUUIDStripsPrefix() {
        XCTAssertEqual(TerminalRef.itermUUID(from: "w0t1p0:ABC-123"), "ABC-123")
        XCTAssertEqual(TerminalRef.itermUUID(from: "ABC-123"), "ABC-123")
    }

    func testSessionStartRegistersAsWorking() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart))
        let s = store.snapshot()
        XCTAssertEqual(s.count, 1)
        XCTAssertEqual(s[0].state, .working)
        XCTAssertEqual(s[0].terminal, .iterm(uuid: "UUID-1"))
        XCTAssertEqual(s[0].key, "UUID-1")
    }

    func testPreToolUseSetsWorkingWithTool() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart))
        _ = store.apply(event(.preToolUse, tool: "Edit"))
        XCTAssertEqual(store.snapshot()[0].state, .working)
        XCTAssertEqual(store.snapshot()[0].currentTool, "Edit")
    }

    func testNotificationMatchersMapToStates() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart))
        _ = store.apply(event(.notification, matcher: "needs_input"))
        XCTAssertEqual(store.snapshot()[0].state, .needsInput)
        _ = store.apply(event(.notification, matcher: "permission_prompt"))
        XCTAssertEqual(store.snapshot()[0].state, .needsPermission)
    }

    func testPermissionRequestMapsToNeedsPermission() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart))
        _ = store.apply(event(.permissionRequest))
        XCTAssertEqual(store.snapshot()[0].state, .needsPermission)
    }

    func testStopEmitsDoneSoundAndState() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart))
        let fx = store.apply(event(.stop))
        XCTAssertEqual(store.snapshot()[0].state, .done)
        XCTAssertEqual(fx, [.soundDone])
    }

    func testStopFailureEmitsFailedSound() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart))
        let fx = store.apply(event(.stopFailure))
        XCTAssertEqual(store.snapshot()[0].state, .failed)
        XCTAssertEqual(fx, [.soundFailed])
    }

    func testEventWithoutSessionStartAutoRegisters() {
        let store = SessionStore()
        _ = store.apply(event(.stop))          // no prior SessionStart
        XCTAssertEqual(store.snapshot().count, 1)
        XCTAssertEqual(store.snapshot()[0].state, .done)
    }

    func testPurgeRemovesEndedAfterGraceAndStale() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart, session: "keep", iterm: "w0t0p0:K"))
        _ = store.apply(event(.sessionEnd, session: "gone", iterm: "w0t0p0:G"))
        // ended session older than grace, and no stale removal for the fresh one
        store.purge(now: Date(timeIntervalSince1970: t + 10), endedGrace: 5, staleTimeout: 3600)
        let keys = store.snapshot().map(\.key)
        XCTAssertEqual(keys, ["K"])
    }

    func testSnapshotSortsAttentionFirst() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart, session: "a", iterm: "w0t0p0:A")) // working
        _ = store.apply(event(.notification, session: "b", matcher: "permission_prompt", iterm: "w0t0p0:B"))
        XCTAssertEqual(store.snapshot().first?.key, "B") // needsPermission first
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SessionStoreTests`
Expected: FAIL — `SessionStore`/`Session`/`TerminalRef` not defined.

- [ ] **Step 3: Implement `Session.swift`**

```swift
import Foundation

public enum SessionState: Sendable, Equatable {
    case working, needsInput, needsPermission, done, failed, ended
}

public enum TerminalRef: Sendable, Equatable {
    case iterm(uuid: String)
    case other(termProgram: String?, pid: Int?)

    /// `ITERM_SESSION_ID` looks like `w0t1p0:UUID`; the AppleScript session id is the UUID suffix.
    public static func itermUUID(from raw: String) -> String {
        if let colon = raw.lastIndex(of: ":") { return String(raw[raw.index(after: colon)...]) }
        return raw
    }

    public static func from(_ env: HookEnv) -> TerminalRef {
        if let raw = env.itermSessionID, !raw.isEmpty {
            return .iterm(uuid: itermUUID(from: raw))
        }
        return .other(termProgram: env.termProgram, pid: env.pid)
    }
}

public struct Session: Identifiable, Sendable, Equatable {
    public var id: String { key }
    public let key: String
    public var claudeSessionID: String
    public var terminal: TerminalRef
    public var cwd: String
    public var title: String?
    public var model: String?
    public var state: SessionState
    public var currentTool: String?
    public var startedAt: Date
    public var lastEventAt: Date
}
```

- [ ] **Step 4: Implement `SessionStore.swift`**

```swift
import Foundation

public enum SessionEffect: Sendable, Equatable { case soundDone, soundFailed }

public final class SessionStore {
    private var sessions: [String: Session] = [:]
    public init() {}

    private func key(for event: HookEvent) -> String {
        if let raw = event.env.itermSessionID, !raw.isEmpty {
            return TerminalRef.itermUUID(from: raw)
        }
        return event.sessionID
    }

    private func title(fromCwd cwd: String) -> String? {
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty ? nil : name
    }

    @discardableResult
    public func apply(_ event: HookEvent) -> [SessionEffect] {
        let k = key(for: event)
        var s = sessions[k] ?? Session(
            key: k, claudeSessionID: event.sessionID, terminal: .from(event.env),
            cwd: event.cwd, title: title(fromCwd: event.cwd), model: nil,
            state: .working, currentTool: nil, startedAt: event.receivedAt, lastEventAt: event.receivedAt
        )
        s.lastEventAt = event.receivedAt
        if s.cwd.isEmpty { s.cwd = event.cwd }
        if case .other = s.terminal, case .iterm = TerminalRef.from(event.env) {
            s.terminal = .from(event.env) // upgrade if we learn the iTerm id later
        }
        var effects: [SessionEffect] = []

        switch event.name {
        case .sessionStart:
            s.state = .working
        case .preToolUse:
            s.state = .working
            if let tool = event.toolName { s.currentTool = tool }
        case .notification:
            switch event.matcher {
            case "permission_prompt": s.state = .needsPermission
            case "needs_input", "idle_prompt", "elicitation_dialog", "agent_needs_input":
                s.state = .needsInput
            default: break // informational notifications don't change state
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

        sessions[k] = s
        return effects
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter SessionStoreTests`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: Session model and pure SessionStore state machine" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: TerminalJumper protocol + registry routing

**Files:**
- Create: `Sources/ClaudeNotchCore/Terminal/TerminalJumper.swift`
- Create: `Tests/ClaudeNotchCoreTests/TerminalJumperRegistryTests.swift`

**Interfaces:**
- Consumes: `Session`, `TerminalRef` (Task 3).
- Produces:
  - `enum JumpResult: Sendable, Equatable { case jumped, fellBack, failed(String) }`
  - `protocol TerminalJumper: Sendable { func jump(to session: Session) async -> JumpResult }`
  - `final class TerminalJumperRegistry { init(iterm: TerminalJumper, fallback: TerminalJumper); func jumper(for session: Session) -> TerminalJumper }`

- [ ] **Step 1: Write the failing test**

`Tests/ClaudeNotchCoreTests/TerminalJumperRegistryTests.swift`:
```swift
import XCTest
@testable import ClaudeNotchCore

private final class FakeJumper: TerminalJumper, @unchecked Sendable {
    let label: String
    init(_ label: String) { self.label = label }
    func jump(to session: Session) async -> JumpResult { .failed(label) }
}

final class TerminalJumperRegistryTests: XCTestCase {
    private func session(_ term: TerminalRef) -> Session {
        Session(key: "k", claudeSessionID: "s", terminal: term, cwd: "/w", title: nil,
                model: nil, state: .working, currentTool: nil, startedAt: .init(), lastEventAt: .init())
    }

    func testRoutesITermToItermJumper() async {
        let reg = TerminalJumperRegistry(iterm: FakeJumper("iterm"), fallback: FakeJumper("fallback"))
        let result = await reg.jumper(for: session(.iterm(uuid: "U"))).jump(to: session(.iterm(uuid: "U")))
        XCTAssertEqual(result, .failed("iterm"))
    }

    func testRoutesOtherToFallback() async {
        let reg = TerminalJumperRegistry(iterm: FakeJumper("iterm"), fallback: FakeJumper("fallback"))
        let result = await reg.jumper(for: session(.other(termProgram: "Ghostty", pid: 1)))
            .jump(to: session(.other(termProgram: "Ghostty", pid: 1)))
        XCTAssertEqual(result, .failed("fallback"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter TerminalJumperRegistryTests`
Expected: FAIL — `TerminalJumper`/`TerminalJumperRegistry` not defined.

- [ ] **Step 3: Implement `TerminalJumper.swift`**

```swift
import Foundation

public enum JumpResult: Sendable, Equatable {
    case jumped
    case fellBack
    case failed(String)
}

public protocol TerminalJumper: Sendable {
    func jump(to session: Session) async -> JumpResult
}

/// Routes a session to the right jumper by terminal kind. New terminals (Ghostty, tmux…)
/// register here in v2 without touching callers.
public final class TerminalJumperRegistry {
    private let iterm: TerminalJumper
    private let fallback: TerminalJumper

    public init(iterm: TerminalJumper, fallback: TerminalJumper) {
        self.iterm = iterm
        self.fallback = fallback
    }

    public func jumper(for session: Session) -> TerminalJumper {
        switch session.terminal {
        case .iterm: return iterm
        case .other: return fallback
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter TerminalJumperRegistryTests`
Expected: both PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: TerminalJumper protocol and registry routing" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Paths + BridgeConfig (write/read, 0600)

**Files:**
- Create: `Sources/ClaudeNotchCore/Config/Paths.swift`
- Create: `Sources/ClaudeNotchCore/Config/BridgeConfig.swift`
- Create: `Tests/ClaudeNotchCoreTests/BridgeConfigTests.swift`

**Interfaces:**
- Produces:
  - `enum Paths { static var appSupportDir: URL; static var bridgeConfigURL: URL; static var claudeSettingsURL: URL }`
  - `struct BridgeConfig: Codable, Equatable, Sendable { let port: UInt16; let token: String }`
  - `enum BridgeConfigWriter { static func write(_ c: BridgeConfig, to url: URL) throws; static func read(from url: URL) throws -> BridgeConfig }`

- [ ] **Step 1: Write the failing test**

`Tests/ClaudeNotchCoreTests/BridgeConfigTests.swift`:
```swift
import XCTest
@testable import ClaudeNotchCore

final class BridgeConfigTests: XCTestCase {
    func testRoundTripAndPermissions() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bridge-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let cfg = BridgeConfig(port: 51234, token: "secret-token")
        try BridgeConfigWriter.write(cfg, to: url)
        XCTAssertEqual(try BridgeConfigWriter.read(from: url), cfg)

        let perms = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(perms?.int16Value, 0o600)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter BridgeConfigTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Implement `Paths.swift`**

```swift
import Foundation

public enum Paths {
    public static var appSupportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ClaudeNotch", isDirectory: true)
    }
    public static var bridgeConfigURL: URL { appSupportDir.appendingPathComponent("bridge.json") }
    public static var claudeSettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
    }
}
```

- [ ] **Step 4: Implement `BridgeConfig.swift`**

```swift
import Foundation

public struct BridgeConfig: Codable, Equatable, Sendable {
    public let port: UInt16
    public let token: String
    public init(port: UInt16, token: String) { self.port = port; self.token = token }
}

public enum BridgeConfigWriter {
    public static func write(_ config: BridgeConfig, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(config)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public static func read(from url: URL) throws -> BridgeConfig {
        try JSONDecoder().decode(BridgeConfig.self, from: Data(contentsOf: url))
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter BridgeConfigTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: Paths and BridgeConfig read/write with 0600 perms" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: HookInstaller (settings.json merge / uninstall / status)

**Files:**
- Create: `Sources/ClaudeNotchCore/Install/HookInstaller.swift`
- Create: `Tests/ClaudeNotchCoreTests/HookInstallerTests.swift`

**Interfaces:**
- Consumes: nothing (operates on a settings.json URL passed in — enables fixture testing).
- Produces:
  - `struct HookInstaller { let helperPath: String; init(helperPath: String); func install(into url: URL) throws; func uninstall(from url: URL) throws; func status(url: URL) throws -> Bool }`
  - Registered events + matchers (each `async:true`, command = `"<helperPath> <Event> [subtype]"`): `SessionStart *`, `PreToolUse *`, `Notification permission_prompt` (→ subtype `permission_prompt`), `Notification idle_prompt|elicitation_dialog|agent_needs_input` (→ subtype `needs_input`), `Stop *`, `StopFailure *`, `SessionEnd *`. Note: v1 does NOT register `PermissionRequest` — the `Notification permission_prompt` matcher fully covers the needs-permission state. `SessionStore` still handles a `.permissionRequest` event defensively if one ever arrives, but no such hook is installed in v1. (v2 may add it, feature-detected.)
  - Our entries are marked by a top-level sentinel command substring: the `helperPath`. Uninstall removes exactly hook entries whose command begins with `helperPath`.

- [ ] **Step 1: Write the failing tests**

`Tests/ClaudeNotchCoreTests/HookInstallerTests.swift`:
```swift
import XCTest
@testable import ClaudeNotchCore

final class HookInstallerTests: XCTestCase {
    private func tmpURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("settings-\(UUID().uuidString).json")
    }
    private func read(_ url: URL) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    }

    func testInstallIntoMissingFileCreatesHooks() throws {
        let url = tmpURL(); defer { try? FileManager.default.removeItem(at: url) }
        let inst = HookInstaller(helperPath: "/App/notch-bridge")
        try inst.install(into: url)
        XCTAssertTrue(try inst.status(url: url))
        let hooks = try read(url)["hooks"] as! [String: Any]
        XCTAssertNotNil(hooks["SessionStart"])
        XCTAssertNotNil(hooks["Stop"])
        let notif = hooks["Notification"] as! [[String: Any]]
        let matchers = notif.map { $0["matcher"] as! String }
        XCTAssertTrue(matchers.contains("permission_prompt"))
    }

    func testInstallPreservesExistingUserHooks() throws {
        let url = tmpURL(); defer { try? FileManager.default.removeItem(at: url) }
        let existing = #"""
        {"model":"opus","hooks":{"Stop":[{"matcher":"*","hooks":[{"type":"command","command":"/usr/bin/my-own-thing"}]}]}}
        """#
        try Data(existing.utf8).write(to: url)
        let inst = HookInstaller(helperPath: "/App/notch-bridge")
        try inst.install(into: url)

        let root = try read(url)
        XCTAssertEqual(root["model"] as? String, "opus") // untouched
        let stop = (root["hooks"] as! [String: Any])["Stop"] as! [[String: Any]]
        let cmds = stop.flatMap { ($0["hooks"] as! [[String: Any]]).map { $0["command"] as! String } }
        XCTAssertTrue(cmds.contains("/usr/bin/my-own-thing"))                 // user hook kept
        XCTAssertTrue(cmds.contains { $0.hasPrefix("/App/notch-bridge") })     // ours added
    }

    func testUninstallRemovesOnlyOurs() throws {
        let url = tmpURL(); defer { try? FileManager.default.removeItem(at: url) }
        let existing = #"""
        {"hooks":{"Stop":[{"matcher":"*","hooks":[{"type":"command","command":"/usr/bin/my-own-thing"}]}]}}
        """#
        try Data(existing.utf8).write(to: url)
        let inst = HookInstaller(helperPath: "/App/notch-bridge")
        try inst.install(into: url)
        try inst.uninstall(from: url)

        XCTAssertFalse(try inst.status(url: url))
        let stop = (try read(url)["hooks"] as! [String: Any])["Stop"] as! [[String: Any]]
        let cmds = stop.flatMap { ($0["hooks"] as! [[String: Any]]).map { $0["command"] as! String } }
        XCTAssertEqual(cmds, ["/usr/bin/my-own-thing"]) // only user hook remains
    }

    func testInstallIsIdempotent() throws {
        let url = tmpURL(); defer { try? FileManager.default.removeItem(at: url) }
        let inst = HookInstaller(helperPath: "/App/notch-bridge")
        try inst.install(into: url)
        try inst.install(into: url)
        let stop = (try read(url)["hooks"] as! [String: Any])["Stop"] as! [[String: Any]]
        let ours = stop.flatMap { ($0["hooks"] as! [[String: Any]]) }
            .filter { ($0["command"] as! String).hasPrefix("/App/notch-bridge") }
        XCTAssertEqual(ours.count, 1) // not duplicated
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter HookInstallerTests`
Expected: FAIL — `HookInstaller` not defined.

- [ ] **Step 3: Implement `HookInstaller.swift`**

```swift
import Foundation

public struct HookInstaller {
    public let helperPath: String
    public init(helperPath: String) { self.helperPath = helperPath }

    /// (event, matcher, subtype-arg). subtype is appended to the helper command so the app
    /// knows the notification kind without relying on stdin contents.
    private var specs: [(event: String, matcher: String, subtype: String?)] {
        [
            ("SessionStart", "*", nil),
            ("PreToolUse", "*", nil),
            ("Notification", "permission_prompt", "permission_prompt"),
            ("Notification", "idle_prompt|elicitation_dialog|agent_needs_input", "needs_input"),
            ("Stop", "*", nil),
            ("StopFailure", "*", nil),
            ("SessionEnd", "*", nil)
        ]
    }

    private func command(event: String, subtype: String?) -> String {
        subtype.map { "\(helperPath) \(event) \($0)" } ?? "\(helperPath) \(event)"
    }

    private func isOurs(_ hook: [String: Any]) -> Bool {
        (hook["command"] as? String)?.hasPrefix(helperPath) ?? false
    }

    private func loadRoot(_ url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func save(_ root: [String: Any], to url: URL) throws {
        // backup existing
        if FileManager.default.fileExists(atPath: url.path) {
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("settings.json.claudenotch-backup")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: url, to: backup)
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: root,
                                              options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic) // temp file + rename
    }

    /// Remove our entries from a hooks dict, dropping now-empty matcher groups and event arrays.
    private func stripOurs(_ hooks: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (event, value) in hooks {
            guard var groups = value as? [[String: Any]] else { result[event] = value; continue }
            groups = groups.compactMap { group in
                guard var inner = group["hooks"] as? [[String: Any]] else { return group }
                inner = inner.filter { !isOurs($0) }
                if inner.isEmpty { return nil }
                var g = group; g["hooks"] = inner; return g
            }
            if !groups.isEmpty { result[event] = groups }
        }
        return result
    }

    public func install(into url: URL) throws {
        var root = try loadRoot(url)
        var hooks = (root["hooks"] as? [String: Any]) ?? [:]
        hooks = stripOurs(hooks) // idempotent: remove any prior ours, then re-add fresh

        for spec in specs {
            var groups = (hooks[spec.event] as? [[String: Any]]) ?? []
            groups.append([
                "matcher": spec.matcher,
                "hooks": [[
                    "type": "command",
                    "command": command(event: spec.event, subtype: spec.subtype),
                    "async": true
                ]]
            ])
            hooks[spec.event] = groups
        }
        root["hooks"] = hooks
        try save(root, to: url)
    }

    public func uninstall(from url: URL) throws {
        var root = try loadRoot(url)
        guard let hooks = root["hooks"] as? [String: Any] else { return }
        let stripped = stripOurs(hooks)
        if stripped.isEmpty { root.removeValue(forKey: "hooks") } else { root["hooks"] = stripped }
        try save(root, to: url)
    }

    public func status(url: URL) throws -> Bool {
        let hooks = (try loadRoot(url)["hooks"] as? [String: Any]) ?? [:]
        for (_, value) in hooks {
            guard let groups = value as? [[String: Any]] else { continue }
            for group in groups {
                let inner = (group["hooks"] as? [[String: Any]]) ?? []
                if inner.contains(where: isOurs) { return true }
            }
        }
        return false
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter HookInstallerTests`
Expected: all 4 PASS.
Run: `swift test`
Expected: entire Core suite PASSES.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: HookInstaller with idempotent, marker-scoped settings.json merge" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: notch-bridge helper (stdin + env → POST)

**Files:**
- Modify: `Sources/notch-bridge/main.swift`

**Interfaces:**
- Consumes: `Paths`, `BridgeConfigWriter`, `BridgeConfig` (Task 5).
- Produces: an executable `notch-bridge <EventName> [subtype]` that reads hook JSON on stdin, injects env, and POSTs to `http://127.0.0.1:<port>/hook/<EventName>` with header `X-ClaudeNotch-Token`. Always exits 0; total timeout ~2s.

- [ ] **Step 1: Implement `Sources/notch-bridge/main.swift`**

```swift
import Foundation
import ClaudeNotchCore

// notch-bridge <EventName> [subtype]
// Reads Claude Code hook JSON on stdin, adds env + matcher, POSTs to the running app.
// Never blocks Claude Code: short timeout, always exits 0.

func run() {
    let args = CommandLine.arguments
    guard args.count >= 2 else { exit(0) }
    let eventName = args[1]
    let subtype: String? = args.count >= 3 ? args[2] : nil

    // Read stdin (hook payload). Empty is acceptable.
    let stdinData = FileHandle.standardInput.readDataToEndOfFile()
    var payload = (try? JSONSerialization.jsonObject(with: stdinData) as? [String: Any]) ?? [:]

    // Inject environment (our precise-jump key + terminal context).
    let env = ProcessInfo.processInfo.environment
    var envOut: [String: Any] = [:]
    if let iterm = env["ITERM_SESSION_ID"] { envOut["ITERM_SESSION_ID"] = iterm }
    if let tp = env["TERM_PROGRAM"] { envOut["TERM_PROGRAM"] = tp }
    envOut["PID"] = String(ProcessInfo.processInfo.processIdentifier)
    payload["env"] = envOut
    if let subtype { payload["matcher"] = subtype }
    payload["hook_event_name"] = eventName

    // Look up the running app's port + token. Absent => app not running => no-op.
    guard let cfg = try? BridgeConfigWriter.read(from: Paths.bridgeConfigURL) else { exit(0) }

    guard let url = URL(string: "http://127.0.0.1:\(cfg.port)/hook/\(eventName)"),
          let body = try? JSONSerialization.data(withJSONObject: payload) else { exit(0) }

    var req = URLRequest(url: url, timeoutInterval: 2.0)
    req.httpMethod = "POST"
    req.httpBody = body
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue(cfg.token, forHTTPHeaderField: "X-ClaudeNotch-Token")

    let sem = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: req) { _, _, _ in sem.signal() }.resume()
    _ = sem.wait(timeout: .now() + 2.5)
    exit(0)
}

run()
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: builds `notch-bridge`.

- [ ] **Step 3: Manual smoke (no app yet → must be a silent no-op)**

Run: `echo '{"session_id":"x","cwd":"/tmp"}' | .build/debug/notch-bridge Stop; echo "exit=$?"`
Expected: `exit=0` and no crash (bridge.json absent → silent no-op). Full POST path is verified in Task 8.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: notch-bridge helper forwards hook events with env capture" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: HookServer (NWListener + minimal HTTP + token)

**Files:**
- Create: `Sources/ClaudeNotchApp/Transport/HookServer.swift`

**Interfaces:**
- Consumes: `HookEvent`, `HookEventName` (Task 2).
- Produces:
  - `static func HookServer.eventName(fromPath path: String) -> HookEventName?`
  - `final class HookServer { init(token: String, onEvent: @escaping (HookEvent) -> Void); func start() throws -> UInt16; func stop() }` — binds `127.0.0.1`, returns the OS-assigned port, rejects wrong/absent token with 401.

- [ ] **Step 1: Implement `HookServer.swift`**

```swift
import Foundation
import Network
import ClaudeNotchCore

public final class HookServer {
    private let token: String
    private let onEvent: (HookEvent) -> Void
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "claudenotch.hookserver")

    public init(token: String, onEvent: @escaping (HookEvent) -> Void) {
        self.token = token
        self.onEvent = onEvent
    }

    public static func eventName(fromPath path: String) -> HookEventName? {
        // path like "/hook/Stop"
        guard let last = path.split(separator: "/").last else { return nil }
        return HookEventName(rawValue: String(last))
    }

    public func start() throws -> UInt16 {
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback          // 127.0.0.1 only
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params)      // OS-assigned ephemeral port
        self.listener = listener

        listener.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }

        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            if case .ready = state { ready.signal() }
            if case .failed = state { ready.signal() }
        }
        listener.start(queue: queue)
        _ = ready.wait(timeout: .now() + 3)
        guard let port = listener.port?.rawValue else {
            throw NSError(domain: "HookServer", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "listener did not bind"])
        }
        return port
    }

    public func stop() { listener?.cancel(); listener = nil }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        receive(conn, buffer: Data())
    }

    private func receive(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }

            if let (headers, body, complete) = Self.tryParse(buf) {
                if complete {
                    self.respond(conn, headers: headers, body: body)
                    return
                }
            }
            if error != nil || isComplete {
                conn.cancel(); return
            }
            self.receive(conn, buffer: buf)
        }
    }

    /// Returns (headerLines, body, isComplete) once full headers are present; isComplete true when
    /// the whole Content-Length body has arrived.
    private static func tryParse(_ buf: Data) -> (headers: [String], body: Data, isComplete: Bool)? {
        guard let sep = buf.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = buf.subdata(in: buf.startIndex..<sep.lowerBound)
        guard let headerStr = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = headerStr.components(separatedBy: "\r\n")
        let length = lines.first(where: { $0.lowercased().hasPrefix("content-length:") })
            .flatMap { Int($0.split(separator: ":")[1].trimmingCharacters(in: .whitespaces)) } ?? 0
        let bodyStart = sep.upperBound
        let have = buf.distance(from: bodyStart, to: buf.endIndex)
        let body = buf.subdata(in: bodyStart..<buf.endIndex)
        return (lines, body, have >= length)
    }

    private func respond(_ conn: NWConnection, headers: [String], body: Data) {
        let requestLine = headers.first ?? ""
        let parts = requestLine.split(separator: " ")
        let path = parts.count >= 2 ? String(parts[1]) : ""
        let sentToken = headers.first(where: { $0.lowercased().hasPrefix("x-claudenotch-token:") })
            .map { $0.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces) }

        var status = "200 OK"
        if sentToken != token {
            status = "401 Unauthorized"
        } else if let name = Self.eventName(fromPath: path),
                  let event = try? HookEvent.decode(body, name: name, now: Date()) {
            onEvent(event)
        } else {
            status = "400 Bad Request"
        }

        let response = "HTTP/1.1 \(status)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        conn.send(content: Data(response.utf8), completion: .contentProcessed { _ in conn.cancel() })
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: builds.

- [ ] **Step 3: Manual smoke via a throwaway harness + curl**

Temporarily add to `Sources/ClaudeNotchApp/main.swift` (replace stub):
```swift
import Foundation
import ClaudeNotchCore

let server = HookServer(token: "tok") { event in
    print("EVENT \(event.name.rawValue) session=\(event.sessionID) iterm=\(event.env.itermSessionID ?? "-")")
}
let port = try server.start()
print("listening on \(port)")
RunLoop.main.run()
```

Run (terminal A): `swift run ClaudeNotchApp`
Run (terminal B):
```bash
curl -s -X POST "http://127.0.0.1:<PORT>/hook/Stop" \
  -H "X-ClaudeNotch-Token: tok" \
  -d '{"session_id":"s1","cwd":"/w","env":{"ITERM_SESSION_ID":"w0t0p0:UUID"}}' -o /dev/null -w "%{http_code}\n"
```
Expected: curl prints `200`; terminal A prints `EVENT Stop session=s1 iterm=w0t0p0:UUID`.
Then test auth: same curl with a wrong token → `401`, no EVENT line.

Revert `main.swift` back to the stub after verifying (the real coordinator arrives in Task 12).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: localhost HookServer with minimal HTTP parsing and token auth" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: ITerm2Jumper + FallbackActivator

**Files:**
- Create: `Sources/ClaudeNotchApp/Terminal/ITerm2Jumper.swift`
- Create: `Sources/ClaudeNotchApp/Terminal/FallbackActivator.swift`

**Interfaces:**
- Consumes: `TerminalJumper`, `JumpResult`, `Session`, `TerminalRef` (Tasks 3–4).
- Produces: `struct ITerm2Jumper: TerminalJumper` and `struct FallbackActivator: TerminalJumper`.

- [ ] **Step 1: Implement `ITerm2Jumper.swift`**

```swift
import Foundation
import AppKit
import ClaudeNotchCore

/// Focuses a specific iTerm2 window→tab→split by matching the AppleScript session `id`
/// (the UUID suffix of ITERM_SESSION_ID).
public struct ITerm2Jumper: TerminalJumper {
    public init() {}

    public func jump(to session: Session) async -> JumpResult {
        guard case let .iterm(uuid) = session.terminal else { return .failed("not an iTerm session") }
        let script = Self.script(uuid: uuid)
        return await MainActor.run {
            var errorInfo: NSDictionary?
            guard let apple = NSAppleScript(source: script) else { return .failed("bad script") }
            let out = apple.executeAndReturnError(&errorInfo)
            if let errorInfo { return .failed("\(errorInfo)") }
            return out.booleanValue ? .jumped : .fellBack
        }
    }

    static func script(uuid: String) -> String {
        // Returns true if a matching session was found and selected.
        """
        tell application "iTerm2"
            activate
            repeat with aWindow in windows
                repeat with aTab in tabs of aWindow
                    repeat with aSession in sessions of aTab
                        if (id of aSession) is "\(uuid)" then
                            select aWindow
                            select aTab
                            select aSession
                            return true
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        return false
        """
    }
}
```

- [ ] **Step 2: Implement `FallbackActivator.swift`**

```swift
import Foundation
import AppKit
import ClaudeNotchCore

/// Best-effort: raise the terminal app by its TERM_PROGRAM name. No precise pane targeting.
public struct FallbackActivator: TerminalJumper {
    public init() {}

    public func jump(to session: Session) async -> JumpResult {
        let appName: String?
        if case let .other(termProgram, _) = session.terminal {
            appName = termProgram?.replacingOccurrences(of: ".app", with: "")
        } else { appName = nil }

        return await MainActor.run {
            let apps = NSWorkspace.shared.runningApplications
            if let name = appName,
               let app = apps.first(where: { $0.localizedName == name || $0.bundleIdentifier?.contains(name.lowercased()) == true }) {
                app.activate(options: [.activateAllWindows])
                return .fellBack
            }
            return .failed("terminal app not found")
        }
    }
}
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: builds.

- [ ] **Step 4: Manual smoke (real iTerm2)**

In an iTerm2 session, run `echo $ITERM_SESSION_ID` (note the UUID after the colon). Temporarily point `main.swift` at a harness:
```swift
import ClaudeNotchCore
let uuid = TerminalRef.itermUUID(from: ProcessInfo.processInfo.environment["ITERM_SESSION_ID"] ?? "")
let s = Session(key: uuid, claudeSessionID: "s", terminal: .iterm(uuid: uuid), cwd: "/", title: nil,
                model: nil, state: .working, currentTool: nil, startedAt: .init(), lastEventAt: .init())
Task { print(await ITerm2Jumper().jump(to: s)); exit(0) }
RunLoop.main.run()
```
Switch to a different tab, then `swift run ClaudeNotchApp` from that same iTerm session.
Expected: iTerm raises and selects the original session's pane; prints `jumped`. First run triggers a macOS Automation permission prompt — approve it (System Settings ▸ Privacy & Security ▸ Automation). Revert `main.swift` to the stub after.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: iTerm2 AppleScript precise jump and fallback activator" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: SoundPlayer

**Files:**
- Create: `Sources/ClaudeNotchApp/Sound/SoundPlayer.swift`

**Interfaces:**
- Consumes: `SessionEffect` (Task 3).
- Produces: `final class SoundPlayer { var enabled: Bool; init(enabled: Bool); func play(_ effect: SessionEffect) }`.

- [ ] **Step 1: Implement `SoundPlayer.swift`**

```swift
import AppKit
import ClaudeNotchCore

public final class SoundPlayer {
    public var enabled: Bool
    public init(enabled: Bool = true) { self.enabled = enabled }

    public func play(_ effect: SessionEffect) {
        guard enabled else { return }
        let name: NSSound.Name = (effect == .soundFailed) ? "Basso" : "Glass"
        NSSound(named: name)?.play()
    }
}
```

- [ ] **Step 2: Build + manual smoke**

Run: `swift build`
Expected: builds. (Audible verification happens in the Task 12 end-to-end run.)

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: SoundPlayer for done/failed completion sounds" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: NotchController + SwiftUI views

**Files:**
- Create: `Sources/ClaudeNotchApp/UI/NotchViews.swift`
- Create: `Sources/ClaudeNotchApp/UI/NotchController.swift`

**Interfaces:**
- Consumes: `Session`, `SessionState` (Task 3); DynamicNotchKit.
- Produces:
  - `@MainActor final class NotchViewModel: ObservableObject { @Published var sessions: [Session]; var onJump: ((Session) -> Void)? }`
  - `@MainActor final class NotchController { init(); var onJump: ((Session) -> Void)?; func update(_ sessions: [Session]) }`
- Note: DynamicNotchKit's exact initializer/`expand`/`compact`/`hide` API should be confirmed against the resolved version (`.build/checkouts/DynamicNotchKit`). The controller is a thin wrapper so any API drift is isolated to this file.

- [ ] **Step 1: Implement `NotchViews.swift`**

```swift
import SwiftUI
import ClaudeNotchCore

@MainActor
final class NotchViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    var onJump: ((Session) -> Void)?
}

extension SessionState {
    var glyph: String {
        switch self {
        case .needsPermission: return "🟠"
        case .needsInput: return "🟡"
        case .working: return "🔵"
        case .done: return "✅"
        case .failed: return "❌"
        case .ended: return "⚪️"
        }
    }
    var label: String {
        switch self {
        case .needsPermission: return "needs permission"
        case .needsInput: return "needs input"
        case .working: return "working"
        case .done: return "done"
        case .failed: return "failed"
        case .ended: return "ended"
        }
    }
}

struct NotchExpandedView: View {
    @ObservedObject var vm: NotchViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if vm.sessions.isEmpty {
                Text("No active Claude Code sessions").foregroundStyle(.secondary)
            }
            ForEach(vm.sessions) { s in
                Button { vm.onJump?(s) } label: {
                    HStack(spacing: 8) {
                        Text(s.state.glyph)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(s.title ?? s.claudeSessionID).font(.system(size: 13, weight: .semibold))
                            Text(s.state.label + (s.currentTool.map { " · \($0)" } ?? ""))
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("↵").foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 320)
    }
}

struct NotchCompactView: View {
    @ObservedObject var vm: NotchViewModel
    var body: some View {
        let waiting = vm.sessions.filter { $0.state == .needsInput || $0.state == .needsPermission }.count
        let working = vm.sessions.filter { $0.state == .working }.count
        HStack(spacing: 6) {
            if waiting > 0 { Text("🟠\(waiting)") }
            if working > 0 { Text("🔵\(working)") }
        }.font(.system(size: 12, weight: .medium)).padding(.horizontal, 8)
    }
}
```

- [ ] **Step 2: Implement `NotchController.swift`**

```swift
import SwiftUI
import DynamicNotchKit
import ClaudeNotchCore

@MainActor
public final class NotchController {
    private let vm = NotchViewModel()
    private var notch: DynamicNotch<AnyView, AnyView, AnyView>?
    public var onJump: ((Session) -> Void)? {
        didSet { vm.onJump = onJump }
    }

    public init() {
        let vm = self.vm
        notch = DynamicNotch(
            expanded: { AnyView(NotchExpandedView(vm: vm)) },
            compactLeading: { AnyView(NotchCompactView(vm: vm)) },
            compactTrailing: { AnyView(EmptyView()) }
        )
    }

    /// Update the rendered sessions and show/hide the notch based on whether anything is active.
    public func update(_ sessions: [Session]) {
        vm.sessions = sessions
        Task {
            if sessions.isEmpty {
                await notch?.hide()
            } else {
                await notch?.compact()
            }
        }
    }
}
```
If the resolved DynamicNotchKit API differs (initializer labels or `compact()`/`expand()` names), adapt only this file to the checked-out source in `.build/checkouts/DynamicNotchKit`.

- [ ] **Step 3: Build**

Run: `swift build`
Expected: builds (adjust to the actual DynamicNotchKit API if the compiler flags a mismatch — isolated to `NotchController.swift`).

- [ ] **Step 4: Manual smoke**

Temporarily set `main.swift` to a harness that shows two fake sessions:
```swift
import AppKit
import ClaudeNotchCore
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Task { @MainActor in
    let nc = NotchController()
    nc.onJump = { print("jump \($0.title ?? $0.key)") }
    nc.update([
        Session(key: "A", claudeSessionID: "a", terminal: .iterm(uuid: "A"), cwd: "/w/api",
                title: "api", model: nil, state: .needsPermission, currentTool: "Bash",
                startedAt: .init(), lastEventAt: .init()),
        Session(key: "B", claudeSessionID: "b", terminal: .iterm(uuid: "B"), cwd: "/w/web",
                title: "web", model: nil, state: .working, currentTool: "Edit",
                startedAt: .init(), lastEventAt: .init())
    ])
}
app.run()
```
Run: `swift run ClaudeNotchApp`
Expected: the notch shows `🟠1 🔵2`-style compact content; hovering/expanding lists the two sessions; clicking a row prints `jump …`. Revert `main.swift` after.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: NotchController and SwiftUI notch views via DynamicNotchKit" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: AppCoordinator + app entry point (end-to-end)

**Files:**
- Create: `Sources/ClaudeNotchApp/AppCoordinator.swift`
- Modify: `Sources/ClaudeNotchApp/main.swift` (final version)

**Interfaces:**
- Consumes: everything above — `HookServer`, `SessionStore`, `NotchController`, `TerminalJumperRegistry`, `ITerm2Jumper`, `FallbackActivator`, `SoundPlayer`, `HookInstaller`, `BridgeConfigWriter`, `Paths`.
- Produces: `@MainActor final class AppCoordinator: NSObject, NSApplicationDelegate` — the composition root that starts the server, writes `bridge.json`, installs hooks, wires events → store → notch/sound, routes jumps, and runs the GC timer.

- [ ] **Step 1: Implement `AppCoordinator.swift`**

```swift
import AppKit
import Foundation
import ClaudeNotchCore

@MainActor
public final class AppCoordinator: NSObject, NSApplicationDelegate {
    private let store = SessionStore()
    private let notch = NotchController()
    private let sound = SoundPlayer()
    private let registry = TerminalJumperRegistry(iterm: ITerm2Jumper(), fallback: FallbackActivator())
    private var server: HookServer?
    private var gcTimer: Timer?

    private let endedGrace: TimeInterval = 8
    private let staleTimeout: TimeInterval = 30 * 60

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let token = UUID().uuidString

        // 1. Start server (OS-assigned loopback port).
        let server = HookServer(token: token) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        self.server = server
        guard let port = try? server.start() else {
            NSLog("ClaudeNotch: failed to start hook server"); return
        }

        // 2. Publish port + token for the helper.
        try? BridgeConfigWriter.write(BridgeConfig(port: port, token: token), to: Paths.bridgeConfigURL)

        // 3. Install hooks (idempotent), pointing at the sibling helper binary.
        if let helper = helperPath() {
            try? HookInstaller(helperPath: helper).install(into: Paths.claudeSettingsURL)
        }

        // 4. Route notch clicks to the right jumper.
        notch.onJump = { [weak self] session in
            Task { @MainActor in _ = await self?.registry.jumper(for: session).jump(to: session) }
        }

        // 5. GC timer.
        gcTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.collectGarbage() }
        }

        setupMenuBar()
        notch.update(store.snapshot())
    }

    private func handle(_ event: HookEvent) {
        let effects = store.apply(event)
        effects.forEach(sound.play)
        notch.update(store.snapshot())
    }

    private func collectGarbage() {
        store.purge(now: Date(), endedGrace: endedGrace, staleTimeout: staleTimeout)
        notch.update(store.snapshot())
    }

    private func helperPath() -> String? {
        // notch-bridge sits next to the app executable (same .build dir or bundle Helpers dir).
        guard let dir = Bundle.main.executableURL?.deletingLastPathComponent() else { return nil }
        let candidate = dir.appendingPathComponent("notch-bridge").path
        return FileManager.default.fileExists(atPath: candidate) ? candidate : candidate
    }

    // Minimal menu-bar control (install/uninstall hooks, sound toggle, quit).
    private var statusItem: NSStatusItem?
    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "◗"
        let menu = NSMenu()
        menu.addItem(withTitle: "Reinstall hooks", action: #selector(reinstall), keyEquivalent: "")
        menu.addItem(withTitle: "Uninstall hooks", action: #selector(uninstall), keyEquivalent: "")
        let soundItem = NSMenuItem(title: "Sound", action: #selector(toggleSound), keyEquivalent: "")
        soundItem.state = sound.enabled ? .on : .off
        menu.addItem(soundItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit ClaudeNotch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func reinstall() {
        if let helper = helperPath() { try? HookInstaller(helperPath: helper).install(into: Paths.claudeSettingsURL) }
    }
    @objc private func uninstall() {
        if let helper = helperPath() { try? HookInstaller(helperPath: helper).uninstall(from: Paths.claudeSettingsURL) }
    }
    @objc private func toggleSound(_ item: NSMenuItem) {
        sound.enabled.toggle(); item.state = sound.enabled ? .on : .off
    }

    public func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
    }
}
```

- [ ] **Step 2: Implement final `main.swift`**

```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)      // no Dock icon; never steals focus
let delegate = AppCoordinator()
app.delegate = delegate
app.run()
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: builds the whole app.

- [ ] **Step 4: End-to-end manual verification**

1. Run: `swift run ClaudeNotchApp` (grant Automation permission for iTerm2 on first jump).
2. Confirm hooks installed: `cat ~/.claude/settings.json` shows entries whose command starts with your `.build/debug/notch-bridge` path; any pre-existing hooks are intact; a `settings.json.claudenotch-backup` exists.
3. In iTerm2, open 2–3 tabs/splits and start a `claude` session in each. As each works, watch the notch reflect 🔵 working; trigger a permission prompt (e.g., ask it to run a command) → notch shows 🟠 needs permission; let one finish → ✅ done + sound.
4. Click a waiting session in the notch → iTerm raises the exact pane.
5. Quit via the menu-bar item → choose "Uninstall hooks" first → confirm `~/.claude/settings.json` no longer contains our entries and user hooks remain.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: AppCoordinator wires end-to-end notch monitor with self-config and menu bar" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage** (spec §-by-§ → task):
- §5 architecture (hooks→helper→HTTP→store→notch→jump) → Tasks 7,8,3,11,9,12 ✓
- §6 components (all) → HookServer T8, HookEvent T2, SessionStore T3, NotchController T11, TerminalJumper(+registry) T4, ITerm2/Fallback T9, SoundPlayer T10, HookInstaller T6, BridgeConfigWriter T5, AppCoordinator T12 ✓
- §7 data model + state machine + GC → T3 ✓
- §8 wire protocol + settings.json (multi-matcher Notification, async, marker, atomic+backup) → T6 (install), T7 (helper payload), T8 (server) ✓
- §9 notch UX (compact/expanded/click/idle-hidden) → T11 ✓
- §10 error handling: port pick (T8 OS-assigned), TCC fallback (T9 fallback + prompt), stale GC (T3/T12), settings.json safety (T6), helper silent no-op (T7), non-iTerm fallback (T9), notchless (DynamicNotchKit T11) ✓
- §11 security: loopback bind + token (T8), 0600 bridge.json (T5), metadata-only (T2 never reads transcript) ✓
- §12 coding standards: protocol+registry (T4), DI in AppCoordinator (T12), pure domain (T3), layering (Core vs App) ✓
- §13 testing: unit tests for HookEvent/SessionStore/Registry/BridgeConfig/HookInstaller (T2–T6); manual for server/helper/jump/UI/e2e ✓
- §14 tech + layout → Package.swift T1, layout matches ✓
- §15 build sequence → Tasks ordered to match ✓
- Gaps: `PermissionRequest` hook registration is documented as feature-detected in the spec; v1 installer relies on `Notification/permission_prompt` (fully covers needs-permission) and the store already handles a `.permissionRequest` event if one ever arrives. Acceptable for v1; noted in T6.

**2. Placeholder scan:** No "TBD"/"add error handling"/"similar to Task N". Every code step has complete code. The only "confirm against installed version" note (DynamicNotchKit API, T11) is a legitimate external-dependency verification, isolated to one thin file, with a concrete fallback instruction — not a placeholder.

**3. Type consistency:** `HookEvent` fields/`decode` signature identical across T2/T3/T8. `SessionStore.apply` returns `[SessionEffect]` used in T3 tests and T12. `TerminalJumper.jump(to:) async -> JumpResult`, `TerminalJumperRegistry(iterm:fallback:)`/`jumper(for:)` consistent T4/T9/T12. `HookInstaller(helperPath:)`/`install(into:)`/`uninstall(from:)`/`status(url:)` consistent T6/T12. `BridgeConfig(port:token:)`, `BridgeConfigWriter.write(_:to:)`/`read(from:)` consistent T5/T7/T12. `NotchController.update(_:)`/`onJump`, `SoundPlayer.play(_:)` consistent T10/T11/T12. Helper command string (`<helperPath> <Event> [subtype]`) matches installer specs (T6) and helper argv parsing (T7). ✓
