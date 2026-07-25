# Multi-Terminal Support (Pluggable Terminal Seam) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the closed two-case terminal model with a pluggable identity/jump seam, and ship precise jump-to-session for WezTerm and Kitty, so future terminals are added in a few additive edits with zero switch surgery.

**Architecture:** Terminal handling splits into two concerns linked by a string `adapterID`: **identity** (pure, env→`TerminalIdentity`, in `ClaudeNotchCore`) resolved by a priority-ordered `TerminalIdentifierRegistry`; and **jumping** (`TerminalJumping` protocol + `TerminalJumperRegistry` that owns the degrade chain, protocol/registry in Core, concrete OS-specific jumpers in `ClaudeNotchApp`). `HookEnv` becomes a generic env bag; the `notch-bridge` env allowlist is data-driven off the registry.

**Tech Stack:** Swift 6 toolchain (language mode v5), SwiftPM, macOS 14+, AppKit (App target only), `NSAppleScript` (iTerm2), `Process` subprocess (WezTerm/Kitty CLIs), XCTest.

## Global Constraints

- Toolchain `swift-tools-version: 6.0`, `swiftLanguageModes: [.v5]`, `platforms: [.macOS(.v14)]` — do not change.
- **`ClaudeNotchCore` must stay AppKit-free** — no `import AppKit`/`Cocoa` in Core. OS-specific jump mechanics live only in `ClaudeNotchApp`.
- **No new external dependencies.** Only Foundation/AppKit and the existing DynamicNotchKit.
- **Curated env allowlist** in the bridge — forward only `TerminalIdentifierRegistry.default.allEnvKeys` (+ `PID`), never the whole environment.
- **Subprocess arguments passed as an argv array** to `Process` — never `sh -c` with interpolated strings.
- **Preserve iTerm2 and generic-terminal behavior byte-for-byte** vs. today.
- **Testing:** add only the three approved seam test groups (identifier resolution, registry degrade-chain, keying). Otherwise only *update* existing tests to new signatures. Do not add other new tests.
- **Commits:** conventional-commits style, no JIRA prefix (this project is no-JIRA), local git only (never push). End every commit message with the `Co-Authored-By` trailer used in this repo.
- **Build/test commands:** `swift build` (all targets must compile), `swift test` (Core tests must pass). Every task ends with both green.

---

### Task 1: Generic `HookEnv` env bag + generic decode (Core)

Convert `HookEnv` from three hardcoded fields to a generic `[String:String]` bag, and make `HookEvent.decode` copy the whole `env` object. Compatibility shims (`init(itermSessionID:…)`, `.itermSessionID`, `.termProgram`) keep every existing caller and test compiling; they are removed in Task 7. This is a pure refactor guarded by the existing test suite.

**Files:**
- Modify: `Sources/ClaudeNotchCore/Model/HookEvent.swift:15-24` (the `HookEnv` struct) and `:60-65` (the `env` decode block)

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `struct HookEnv { var values: [String:String]; var pid: Int? }`
  - `init(values: [String:String] = [:], pid: Int? = nil)`
  - compatibility: `init(itermSessionID: String? = nil, termProgram: String? = nil, pid: Int? = nil)`, computed `var itermSessionID: String?`, computed `var termProgram: String?`

- [ ] **Step 1: Replace the `HookEnv` struct**

In `Sources/ClaudeNotchCore/Model/HookEvent.swift`, replace the current struct (lines 15-24):

```swift
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
```

with the generic bag plus compatibility shims:

```swift
public struct HookEnv: Sendable, Equatable {
    /// Raw environment variables forwarded by the bridge (e.g. ITERM_SESSION_ID, WEZTERM_PANE).
    public var values: [String: String]
    public var pid: Int?

    public init(values: [String: String] = [:], pid: Int? = nil) {
        self.values = values
        self.pid = pid
    }

    /// Convenience for a standard cross-terminal variable.
    public var termProgram: String? { values["TERM_PROGRAM"] }

    // --- Compatibility shims (removed in Task 7 once all call sites use `values`) ---
    public init(itermSessionID: String? = nil, termProgram: String? = nil, pid: Int? = nil) {
        var v: [String: String] = [:]
        if let itermSessionID { v["ITERM_SESSION_ID"] = itermSessionID }
        if let termProgram { v["TERM_PROGRAM"] = termProgram }
        self.init(values: v, pid: pid)
    }
    public var itermSessionID: String? { values["ITERM_SESSION_ID"] }
}
```

- [ ] **Step 2: Rewrite the decode `env` block**

In the same file, replace the current `env` parsing (lines 60-65):

```swift
        var env = HookEnv()
        if let e = obj["env"] as? [String: Any] {
            env.itermSessionID = e["ITERM_SESSION_ID"] as? String
            env.termProgram = e["TERM_PROGRAM"] as? String
            if let p = e["PID"] as? String { env.pid = Int(p) } else if let p = e["PID"] as? Int { env.pid = p }
        }
```

with a generic copy of every string-valued key:

```swift
        var values: [String: String] = [:]
        if let e = obj["env"] as? [String: Any] {
            for (k, v) in e {
                if let s = v as? String { values[k] = s }
                else if let n = v as? Int { values[k] = String(n) }
            }
        }
        let env = HookEnv(values: values, pid: values["PID"].flatMap(Int.init))
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: builds with no errors (shims keep `SessionKey`, `Session.from`, and callers compiling).

- [ ] **Step 4: Run the existing suite**

Run: `swift test`
Expected: PASS. `HookEventTests` still reads `e.env.itermSessionID` / `e.env.termProgram` (now computed) and `SessionStoreTests`/`DecisionTests` still construct `HookEnv(itermSessionID:)` (now the shim).

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchCore/Model/HookEvent.swift
git commit -m "$(cat <<'EOF'
refactor: make HookEnv a generic env bag with generic decode

Store all forwarded env vars in a [String:String] bag; decode copies the
whole env object. Compatibility shims keep existing callers/tests green
until the terminal-identity flip.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `TerminalIdentity` + identifier seam + registry (Core, TDD)

Add the pure identity layer: the `TerminalIdentity` value, the `TerminalIdentifying` protocol, the four identifiers, the `TerminalIdentifierRegistry`, and an identity-based `SessionKey.derive` overload (added alongside the existing env-based one so nothing breaks yet). All additive; existing code untouched. Includes the approved identifier-resolution and keying tests.

**Files:**
- Create: `Sources/ClaudeNotchCore/Model/TerminalIdentity.swift`
- Create: `Sources/ClaudeNotchCore/Terminal/TerminalIdentifying.swift`
- Create: `Sources/ClaudeNotchCore/Terminal/TerminalIdentifierRegistry.swift`
- Modify: `Sources/ClaudeNotchCore/Model/SessionKey.swift` (add identity overload)
- Test: `Tests/ClaudeNotchCoreTests/TerminalIdentifierTests.swift` (new)

**Interfaces:**
- Consumes: `HookEnv` (`.values`, `.termProgram`, `.pid`) from Task 1.
- Produces:
  - `struct TerminalIdentity: Sendable, Equatable { let adapterID: String; let handle: String?; let appName: String?; let pid: Int? }` with memberwise `init(adapterID:handle:appName:pid:)` (handle/appName/pid default nil)
  - `protocol TerminalIdentifying: Sendable { var adapterID: String { get }; var priority: Int { get }; var requiredEnvKeys: [String] { get }; func identify(_ env: HookEnv) -> TerminalIdentity? }`
  - concrete: `ITerm2Identifier`, `WezTermIdentifier`, `KittyIdentifier`, `GenericTerminalIdentifier`
  - `final class TerminalIdentifierRegistry` with `init(_ identifiers: [TerminalIdentifying])`, `static let default`, `func resolve(_ env: HookEnv) -> TerminalIdentity`, `func key(for env: HookEnv, sessionID: String) -> String`, `var allEnvKeys: [String]`
  - `SessionKey.derive(identity: TerminalIdentity, sessionID: String) -> String`

- [ ] **Step 1: Write the failing test**

Create `Tests/ClaudeNotchCoreTests/TerminalIdentifierTests.swift`:

```swift
import XCTest
@testable import ClaudeNotchCore

final class TerminalIdentifierTests: XCTestCase {
    private let reg = TerminalIdentifierRegistry.default

    func testITermResolvesToUUIDHandle() {
        let id = reg.resolve(HookEnv(values: ["ITERM_SESSION_ID": "w0t1p0:ABC-123",
                                              "TERM_PROGRAM": "iTerm.app"], pid: 7))
        XCTAssertEqual(id.adapterID, "iterm2")
        XCTAssertEqual(id.handle, "ABC-123")        // colon prefix stripped
        XCTAssertEqual(id.appName, "iTerm.app")
        XCTAssertEqual(id.pid, 7)
    }

    func testITermUUIDWithoutColonPassesThrough() {
        let id = ITerm2Identifier().identify(HookEnv(values: ["ITERM_SESSION_ID": "ABC-123"]))
        XCTAssertEqual(id?.handle, "ABC-123")
    }

    func testWezTermResolvesToPaneHandle() {
        let id = reg.resolve(HookEnv(values: ["WEZTERM_PANE": "42", "TERM_PROGRAM": "WezTerm"]))
        XCTAssertEqual(id.adapterID, "wezterm")
        XCTAssertEqual(id.handle, "42")
    }

    func testKittyResolvesToWindowHandle() {
        let id = reg.resolve(HookEnv(values: ["KITTY_WINDOW_ID": "3"]))
        XCTAssertEqual(id.adapterID, "kitty")
        XCTAssertEqual(id.handle, "3")
    }

    func testUnknownTerminalResolvesToGeneric() {
        let id = reg.resolve(HookEnv(values: ["TERM_PROGRAM": "Ghostty"]))
        XCTAssertEqual(id.adapterID, "generic")
        XCTAssertNil(id.handle)
        XCTAssertEqual(id.appName, "Ghostty")
    }

    func testResolveIsTotalWithEmptyEnv() {
        XCTAssertEqual(reg.resolve(HookEnv()).adapterID, "generic")
    }

    func testSpecificWinsOverGenericByPriority() {
        // iTerm env also carries TERM_PROGRAM (generic's key); specific must win.
        let id = reg.resolve(HookEnv(values: ["ITERM_SESSION_ID": "w0:X", "TERM_PROGRAM": "iTerm.app"]))
        XCTAssertEqual(id.adapterID, "iterm2")
    }

    func testAllEnvKeysIsDedupedUnion() {
        let keys = Set(reg.allEnvKeys)
        XCTAssertEqual(keys, ["ITERM_SESSION_ID", "TERM_PROGRAM", "WEZTERM_PANE", "KITTY_WINDOW_ID"])
    }

    func testKeyUsesHandleElseSessionID() {
        XCTAssertEqual(SessionKey.derive(identity: TerminalIdentity(adapterID: "iterm2", handle: "U-9"),
                                         sessionID: "s1"), "U-9")
        XCTAssertEqual(SessionKey.derive(identity: TerminalIdentity(adapterID: "generic"),
                                         sessionID: "s1"), "s1")
        XCTAssertEqual(reg.key(for: HookEnv(values: ["ITERM_SESSION_ID": "w0:U-9"]), sessionID: "s1"), "U-9")
        XCTAssertEqual(reg.key(for: HookEnv(values: ["TERM_PROGRAM": "Ghostty"]), sessionID: "s1"), "s1")
    }
}
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `swift test --filter TerminalIdentifierTests`
Expected: FAIL — compile errors ("cannot find 'TerminalIdentifierRegistry'/'TerminalIdentity'/'ITerm2Identifier' in scope").

- [ ] **Step 3: Create `TerminalIdentity`**

Create `Sources/ClaudeNotchCore/Model/TerminalIdentity.swift`:

```swift
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
```

- [ ] **Step 4: Create the protocol + identifiers**

Create `Sources/ClaudeNotchCore/Terminal/TerminalIdentifying.swift`:

```swift
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
```

- [ ] **Step 5: Create the registry + `SessionKey` identity overload**

Create `Sources/ClaudeNotchCore/Terminal/TerminalIdentifierRegistry.swift`:

```swift
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
```

In `Sources/ClaudeNotchCore/Model/SessionKey.swift`, add the identity overload **above** the existing `derive(env:sessionID:)` (leave the env one in place for now):

```swift
    /// Stable key from a resolved identity: handle when present, else the Claude session id.
    public static func derive(identity: TerminalIdentity, sessionID: String) -> String {
        if let h = identity.handle, !h.isEmpty { return h }
        return sessionID
    }
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `swift test --filter TerminalIdentifierTests`
Expected: PASS (all cases). Then `swift test` — full suite still green (nothing existing was changed).

- [ ] **Step 7: Commit**

```bash
git add Sources/ClaudeNotchCore/Model/TerminalIdentity.swift \
        Sources/ClaudeNotchCore/Terminal/TerminalIdentifying.swift \
        Sources/ClaudeNotchCore/Terminal/TerminalIdentifierRegistry.swift \
        Sources/ClaudeNotchCore/Model/SessionKey.swift \
        Tests/ClaudeNotchCoreTests/TerminalIdentifierTests.swift
git commit -m "$(cat <<'EOF'
feat: add pluggable terminal identity seam (Core)

TerminalIdentity value + TerminalIdentifying protocol + priority-ordered
TerminalIdentifierRegistry (iTerm2/WezTerm/Kitty/generic) + identity-based
SessionKey.derive overload + allEnvKeys allowlist. Additive; no callers
switched yet.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Flip to `TerminalIdentity` + new jump seam (Core + App, atomic)

Switch `Session.terminal` to `TerminalIdentity`, resolve identity in `SessionStore` and `DecisionRequest.from` via the registry, delete the `TerminalRef` enum, rename the jump protocol to `TerminalJumping` (with `adapterID` + `jump(to identity:)`), rewrite `TerminalJumperRegistry` as a dictionary with the degrade chain, and update the iTerm2/fallback jumpers and `AppCoordinator`. This is one atomic type-flip: it must land together to compile. Ends with `swift build` + `swift test` green.

**Files:**
- Modify: `Sources/ClaudeNotchCore/Model/Session.swift` (terminal type + projectName; delete `TerminalRef`)
- Modify: `Sources/ClaudeNotchCore/Model/SessionKey.swift` (remove env-based `derive`)
- Modify: `Sources/ClaudeNotchCore/Domain/SessionStore.swift` (inject registry; resolve identity in `apply`)
- Modify: `Sources/ClaudeNotchCore/Model/Decision.swift:47-49` (`from` resolves key via registry)
- Modify: `Sources/ClaudeNotchCore/Terminal/TerminalJumper.swift` (protocol rename + registry chain)
- Modify: `Sources/ClaudeNotchApp/Terminal/ITerm2Jumper.swift` (identity signature)
- Modify: `Sources/ClaudeNotchApp/Terminal/FallbackActivator.swift` (identity signature + adapterID)
- Modify: `Sources/ClaudeNotchApp/AppCoordinator.swift:10,58,75,105,112` (registry construction + call sites)
- Test: `Tests/ClaudeNotchCoreTests/TerminalJumperRegistryTests.swift` (rewrite for chain)
- Test: `Tests/ClaudeNotchCoreTests/SessionStoreTests.swift` (identity assertions; drop moved helper)
- Test: `Tests/ClaudeNotchCoreTests/HookEventTests.swift` (drop `testSessionKeyPrefersItermUUID`, now covered)

**Interfaces:**
- Consumes: `TerminalIdentity`, `TerminalIdentifierRegistry`, `SessionKey.derive(identity:sessionID:)` from Task 2.
- Produces:
  - `Session.terminal: TerminalIdentity`
  - `SessionStore.init(identifiers: TerminalIdentifierRegistry = .default)`
  - `DecisionRequest.from(_ event: HookEvent, id: String, identifiers: TerminalIdentifierRegistry = .default) -> DecisionRequest?`
  - `protocol TerminalJumping: Sendable { var adapterID: String { get }; func jump(to identity: TerminalIdentity) async -> JumpResult }`
  - `TerminalJumperRegistry.init(adapters: [TerminalJumping], fallback: TerminalJumping)` and `func jump(to identity: TerminalIdentity) async -> JumpResult`

- [ ] **Step 1: Flip `Session` + delete `TerminalRef`**

In `Sources/ClaudeNotchCore/Model/Session.swift`: delete the entire `TerminalRef` enum (lines 7-23). Change the property (line 29) to:

```swift
    public var terminal: TerminalIdentity
```

Replace the `.other` branch in `projectName` (lines 44-46) so it reads `appName`:

```swift
        if let app = terminal.appName, !app.isEmpty {
            return app.replacingOccurrences(of: ".app", with: "")
        }
```

- [ ] **Step 2: Remove the env-based `SessionKey.derive`**

In `Sources/ClaudeNotchCore/Model/SessionKey.swift`, delete the old `derive(env:sessionID:)` method (the one referencing `TerminalRef.itermUUID`), leaving only the identity overload added in Task 2. The file becomes:

```swift
import Foundation

/// Single source of truth for a session's stable key: the terminal's handle when
/// present, else the Claude session id. Shared by SessionStore and the decision path.
public enum SessionKey {
    public static func derive(identity: TerminalIdentity, sessionID: String) -> String {
        if let h = identity.handle, !h.isEmpty { return h }
        return sessionID
    }
}
```

- [ ] **Step 3: Resolve identity in `SessionStore`**

In `Sources/ClaudeNotchCore/Domain/SessionStore.swift`: add an injected registry and use it in `apply`. Replace the top of the class (the `sessions` property, `init`, and the private `key(for:)` helper, lines 5-11) with:

```swift
public final class SessionStore {
    private var sessions: [String: Session] = [:]
    private let identifiers: TerminalIdentifierRegistry
    public init(identifiers: TerminalIdentifierRegistry = .default) { self.identifiers = identifiers }
```

(Delete the `private func key(for event:)` helper entirely.) Then replace the first two lines of `apply` (currently `let k = key(for: event)` and the `terminal: .from(event.env)` argument, lines 20-22) so identity is resolved once:

```swift
    public func apply(_ event: HookEvent) -> [SessionEffect] {
        let identity = identifiers.resolve(event.env)
        let k = SessionKey.derive(identity: identity, sessionID: event.sessionID)
        var s = sessions[k] ?? Session(
            key: k, claudeSessionID: event.sessionID, terminal: identity,
            cwd: event.cwd, title: title(fromCwd: event.cwd),
```

(Leave the remainder of the `Session(...)` initializer and the rest of `apply` unchanged.)

- [ ] **Step 4: Resolve key via registry in `DecisionRequest.from`**

In `Sources/ClaudeNotchCore/Model/Decision.swift`, change the `from` signature and key line (lines 47-49):

```swift
    static func from(_ event: HookEvent, id: String,
                     identifiers: TerminalIdentifierRegistry = .default) -> DecisionRequest? {
        guard let tool = event.toolName else { return nil }
        let sessionKey = identifiers.key(for: event.env, sessionID: event.sessionID)
```

(The default arg keeps the existing `DecisionRequest.from(event, id:)` call site working.)

- [ ] **Step 5: Rewrite the jump protocol + registry**

Replace the whole of `Sources/ClaudeNotchCore/Terminal/TerminalJumper.swift` with:

```swift
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
```

- [ ] **Step 6: Update `ITerm2Jumper`**

In `Sources/ClaudeNotchApp/Terminal/ITerm2Jumper.swift`, change the type to add `adapterID` and take an identity. Replace the struct declaration and `jump` signature/guard (lines 7-11) with:

```swift
public struct ITerm2Jumper: TerminalJumping {
    public init() {}
    public let adapterID = "iterm2"

    public func jump(to identity: TerminalIdentity) async -> JumpResult {
        guard let uuid = identity.handle, !uuid.isEmpty else { return .failed("no iTerm handle") }
```

(The rest of the method — building `Self.script(uuid: uuid)` and running the AppleScript — is unchanged.)

- [ ] **Step 7: Update `FallbackActivator`**

Replace `Sources/ClaudeNotchApp/Terminal/FallbackActivator.swift` with the identity-based version:

```swift
import Foundation
import AppKit
import ClaudeNotchCore

/// Best-effort: raise the terminal app by its name. No precise pane targeting.
public struct FallbackActivator: TerminalJumping {
    public init() {}
    public let adapterID = "generic"

    public func jump(to identity: TerminalIdentity) async -> JumpResult {
        let appName = identity.appName?.replacingOccurrences(of: ".app", with: "")
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

- [ ] **Step 8: Wire `AppCoordinator`**

In `Sources/ClaudeNotchApp/AppCoordinator.swift`:

Line 10 — construct the registry with adapters + fallback (only iTerm2 for now; WezTerm/Kitty added in Tasks 4-5):

```swift
    private let registry = TerminalJumperRegistry(adapters: [ITerm2Jumper()], fallback: FallbackActivator())
```

Lines 58 and 75 — replace `await self.registry.jumper(for: session).jump(to: session)` (both occurrences) with:

```swift
                let result = await self.registry.jump(to: session.terminal)
```

(At line 75 the local is used in an `if case .failed` immediately after; keep that. If the surrounding line binds it as `let result`, keep the name `result`.)

Lines 105 and 112 — replace `SessionKey.derive(env: event.env, sessionID: event.sessionID)` (both occurrences) with:

```swift
            let ... = TerminalIdentifierRegistry.default.key(for: event.env, sessionID: event.sessionID)
```

i.e. line 105 becomes `let endKey = TerminalIdentifierRegistry.default.key(for: event.env, sessionID: event.sessionID)` and line 112 becomes `let key = TerminalIdentifierRegistry.default.key(for: event.env, sessionID: event.sessionID)`.

- [ ] **Step 9: Rewrite `TerminalJumperRegistryTests` for the chain**

Replace `Tests/ClaudeNotchCoreTests/TerminalJumperRegistryTests.swift` with fakes over the new API:

```swift
import XCTest
@testable import ClaudeNotchCore

private final class FakeJumper: TerminalJumping, @unchecked Sendable {
    let adapterID: String
    let result: JumpResult
    private(set) var called = false
    init(_ adapterID: String, _ result: JumpResult) { self.adapterID = adapterID; self.result = result }
    func jump(to identity: TerminalIdentity) async -> JumpResult { called = true; return result }
}

final class TerminalJumperRegistryTests: XCTestCase {
    private func identity(_ adapterID: String) -> TerminalIdentity {
        TerminalIdentity(adapterID: adapterID, handle: "H")
    }

    func testAdapterJumpedShortCircuits() async {
        let fallback = FakeJumper("generic", .fellBack)
        let reg = TerminalJumperRegistry(adapters: [FakeJumper("iterm2", .jumped)], fallback: fallback)
        let r = await reg.jump(to: identity("iterm2"))
        XCTAssertEqual(r, .jumped)
        XCTAssertFalse(fallback.called)
    }

    func testAdapterFailedFallsBackToFallback() async {
        let fallback = FakeJumper("generic", .fellBack)
        let reg = TerminalJumperRegistry(adapters: [FakeJumper("iterm2", .failed("x"))], fallback: fallback)
        let r = await reg.jump(to: identity("iterm2"))
        XCTAssertEqual(r, .fellBack)
        XCTAssertTrue(fallback.called)
    }

    func testAdapterFellBackDoesNotCallFallback() async {
        let fallback = FakeJumper("generic", .jumped)
        let reg = TerminalJumperRegistry(adapters: [FakeJumper("iterm2", .fellBack)], fallback: fallback)
        let r = await reg.jump(to: identity("iterm2"))
        XCTAssertEqual(r, .fellBack)
        XCTAssertFalse(fallback.called)
    }

    func testUnknownAdapterGoesStraightToFallback() async {
        let fallback = FakeJumper("generic", .fellBack)
        let reg = TerminalJumperRegistry(adapters: [FakeJumper("iterm2", .jumped)], fallback: fallback)
        let r = await reg.jump(to: identity("ghostty"))
        XCTAssertEqual(r, .fellBack)
        XCTAssertTrue(fallback.called)
    }
}
```

- [ ] **Step 10: Update `SessionStoreTests` for identity**

In `Tests/ClaudeNotchCoreTests/SessionStoreTests.swift`:

Delete `testItermUUIDStripsPrefix` (lines 16-19) — the colon-split is now covered by `TerminalIdentifierTests.testITermUUIDWithoutColonPassesThrough` / `testITermResolvesToUUIDHandle`.

Change the terminal assertion in `testSessionStartRegistersAsWorking` (line 27) from the enum form to identity fields:

```swift
        XCTAssertEqual(s[0].terminal.adapterID, "iterm2")
        XCTAssertEqual(s[0].terminal.handle, "UUID-1")
        XCTAssertEqual(s[0].key, "UUID-1")
```

(The `event(...)` helper still constructs `HookEnv(itermSessionID: iterm)` via the Task 1 shim — unchanged here; migrated in Task 7.)

- [ ] **Step 11: Drop the moved keying test from `HookEventTests`**

In `Tests/ClaudeNotchCoreTests/HookEventTests.swift`, delete `testSessionKeyPrefersItermUUID` (lines 54-58). Its behavior is covered by `TerminalIdentifierTests.testKeyUsesHandleElseSessionID`. Leave the decode tests (they read `e.env.itermSessionID`/`termProgram` via shims until Task 7).

- [ ] **Step 12: Build and test**

Run: `swift build`
Expected: all targets compile (App now builds the single-adapter registry).

Run: `swift test`
Expected: PASS — `TerminalIdentifierTests`, rewritten `TerminalJumperRegistryTests`, updated `SessionStoreTests`, and the rest.

- [ ] **Step 13: Commit**

```bash
git add Sources/ClaudeNotchCore/Model/Session.swift \
        Sources/ClaudeNotchCore/Model/SessionKey.swift \
        Sources/ClaudeNotchCore/Domain/SessionStore.swift \
        Sources/ClaudeNotchCore/Model/Decision.swift \
        Sources/ClaudeNotchCore/Terminal/TerminalJumper.swift \
        Sources/ClaudeNotchApp/Terminal/ITerm2Jumper.swift \
        Sources/ClaudeNotchApp/Terminal/FallbackActivator.swift \
        Sources/ClaudeNotchApp/AppCoordinator.swift \
        Tests/ClaudeNotchCoreTests/TerminalJumperRegistryTests.swift \
        Tests/ClaudeNotchCoreTests/SessionStoreTests.swift \
        Tests/ClaudeNotchCoreTests/HookEventTests.swift
git commit -m "$(cat <<'EOF'
refactor: flip terminal handling to TerminalIdentity + jump seam

Session.terminal is now a generic TerminalIdentity resolved via the
identifier registry; TerminalRef is gone. TerminalJumping (adapterID +
jump(to:identity)) + a dictionary TerminalJumperRegistry own the degrade
chain. iTerm2 + generic behavior preserved.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: WezTerm precise jumper + subprocess helper (App)

Add a small subprocess helper (CLI resolution + timed run + app-raise) and the WezTerm jumper that runs `wezterm cli activate-pane`, then register it. Additive. No unit test (shells out to an external binary); covered by manual verification in Task 8.

**Files:**
- Create: `Sources/ClaudeNotchApp/Terminal/TerminalShell.swift`
- Create: `Sources/ClaudeNotchApp/Terminal/WezTermJumper.swift`
- Modify: `Sources/ClaudeNotchApp/AppCoordinator.swift:10` (register the adapter)

**Interfaces:**
- Consumes: `TerminalJumping`, `TerminalIdentity`, `JumpResult` from Task 3.
- Produces:
  - `enum TerminalShell` with `static func resolve(_ name: String) -> String?`, `static func run(_ launchPath: String, _ args: [String], timeout: TimeInterval) -> Bool`, `@MainActor static func raiseApp(named appName: String?) -> Bool`
  - `struct WezTermJumper: TerminalJumping` (`adapterID == "wezterm"`)

- [ ] **Step 1: Create the subprocess helper**

Create `Sources/ClaudeNotchApp/Terminal/TerminalShell.swift`:

```swift
import Foundation
import AppKit

/// Small helpers for CLI-driven terminal jumpers: resolve a binary, run it with a
/// timeout, and raise an app. Keeps WezTerm/Kitty adapters focused on their command.
enum TerminalShell {
    /// GUI apps get a minimal PATH, so search common install dirs explicitly.
    static func resolve(_ name: String) -> String? {
        let dirs = ["/opt/homebrew/bin", "/usr/local/bin",
                    "\(NSHomeDirectory())/.local/bin", "/usr/bin", "/bin"]
        for d in dirs {
            let p = "\(d)/\(name)"
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        return nil
    }

    /// Run `launchPath args` (argv array — no shell). Returns true iff it exits 0 within `timeout`.
    static func run(_ launchPath: String, _ args: [String], timeout: TimeInterval) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        let sem = DispatchSemaphore(value: 0)
        p.terminationHandler = { _ in sem.signal() }
        do { try p.run() } catch { return false }
        if sem.wait(timeout: .now() + timeout) == .timedOut {
            p.terminate()
            return false
        }
        return p.terminationStatus == 0
    }

    /// Bring an app to the front by name. Returns true iff a matching app was found.
    @MainActor static func raiseApp(named appName: String?) -> Bool {
        guard let name = appName?.replacingOccurrences(of: ".app", with: "") else { return false }
        let apps = NSWorkspace.shared.runningApplications
        if let app = apps.first(where: { $0.localizedName == name || $0.bundleIdentifier?.contains(name.lowercased()) == true }) {
            app.activate(options: [.activateAllWindows])
            return true
        }
        return false
    }
}
```

- [ ] **Step 2: Create `WezTermJumper`**

Create `Sources/ClaudeNotchApp/Terminal/WezTermJumper.swift`:

```swift
import Foundation
import ClaudeNotchCore

/// Focuses a WezTerm pane via `wezterm cli activate-pane --pane-id <handle>`, then raises
/// the app so its window comes forward. Degrades to `.failed` (→ registry app-raise) when
/// the CLI is absent or the command fails.
public struct WezTermJumper: TerminalJumping {
    public init() {}
    public let adapterID = "wezterm"

    public func jump(to identity: TerminalIdentity) async -> JumpResult {
        guard let pane = identity.handle, !pane.isEmpty else { return .failed("no wezterm pane") }
        guard let bin = TerminalShell.resolve("wezterm") else { return .failed("wezterm not found") }
        let ok = await Task.detached {
            TerminalShell.run(bin, ["cli", "activate-pane", "--pane-id", pane], timeout: 2.0)
        }.value
        guard ok else { return .failed("wezterm activate-pane failed") }
        _ = await TerminalShell.raiseApp(named: identity.appName ?? "WezTerm")
        return .jumped
    }
}
```

- [ ] **Step 3: Register the adapter**

In `Sources/ClaudeNotchApp/AppCoordinator.swift` line 10, add `WezTermJumper()` to the adapters array:

```swift
    private let registry = TerminalJumperRegistry(adapters: [ITerm2Jumper(), WezTermJumper()], fallback: FallbackActivator())
```

- [ ] **Step 4: Build and test**

Run: `swift build`
Expected: compiles.

Run: `swift test`
Expected: PASS (unchanged Core suite; the new App types aren't unit-tested).

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchApp/Terminal/TerminalShell.swift \
        Sources/ClaudeNotchApp/Terminal/WezTermJumper.swift \
        Sources/ClaudeNotchApp/AppCoordinator.swift
git commit -m "$(cat <<'EOF'
feat: add WezTerm precise jumper via wezterm cli

TerminalShell subprocess helper (resolve/run-with-timeout/raiseApp) +
WezTermJumper (activate-pane by $WEZTERM_PANE handle, then raise app).
Registered in the jumper registry; degrades to app-raise on failure.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Kitty precise jumper (App)

Add the Kitty jumper using `kitty @ focus-window --match id:<handle>`, reusing `TerminalShell`, and register it. Additive; manual verification in Task 8.

**Files:**
- Create: `Sources/ClaudeNotchApp/Terminal/KittyJumper.swift`
- Modify: `Sources/ClaudeNotchApp/AppCoordinator.swift:10` (register the adapter)

**Interfaces:**
- Consumes: `TerminalShell` (Task 4), `TerminalJumping`/`TerminalIdentity`/`JumpResult` (Task 3).
- Produces: `struct KittyJumper: TerminalJumping` (`adapterID == "kitty"`)

- [ ] **Step 1: Create `KittyJumper`**

Create `Sources/ClaudeNotchApp/Terminal/KittyJumper.swift`:

```swift
import Foundation
import ClaudeNotchCore

/// Focuses a Kitty window via `kitty @ focus-window --match id:<handle>`, then raises the app.
/// Requires Kitty remote control to be enabled; degrades to `.failed` (→ registry app-raise)
/// when the CLI is absent, remote control is off, or the command fails.
public struct KittyJumper: TerminalJumping {
    public init() {}
    public let adapterID = "kitty"

    public func jump(to identity: TerminalIdentity) async -> JumpResult {
        guard let win = identity.handle, !win.isEmpty else { return .failed("no kitty window id") }
        guard let bin = TerminalShell.resolve("kitty") else { return .failed("kitty not found") }
        let ok = await Task.detached {
            TerminalShell.run(bin, ["@", "focus-window", "--match", "id:\(win)"], timeout: 2.0)
        }.value
        guard ok else { return .failed("kitty focus-window failed") }
        _ = await TerminalShell.raiseApp(named: identity.appName ?? "kitty")
        return .jumped
    }
}
```

- [ ] **Step 2: Register the adapter**

In `Sources/ClaudeNotchApp/AppCoordinator.swift` line 10, add `KittyJumper()`:

```swift
    private let registry = TerminalJumperRegistry(adapters: [ITerm2Jumper(), WezTermJumper(), KittyJumper()], fallback: FallbackActivator())
```

- [ ] **Step 3: Build and test**

Run: `swift build`
Expected: compiles.

Run: `swift test`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/ClaudeNotchApp/Terminal/KittyJumper.swift \
        Sources/ClaudeNotchApp/AppCoordinator.swift
git commit -m "$(cat <<'EOF'
feat: add Kitty precise jumper via kitty @ focus-window

KittyJumper focuses the window matching $KITTY_WINDOW_ID and raises the
app; degrades to app-raise when remote control/CLI is unavailable.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Data-driven bridge env allowlist (notch-bridge)

Replace the three hardcoded env vars the bridge forwards with the registry's `allEnvKeys` union, so new terminals' env vars flow through automatically.

**Files:**
- Modify: `Sources/notch-bridge/main.swift:24-29` (the env-injection block)

**Interfaces:**
- Consumes: `TerminalIdentifierRegistry.default.allEnvKeys` (Task 2). `notch-bridge` already `import ClaudeNotchCore`.

- [ ] **Step 1: Replace the env-injection block**

In `Sources/notch-bridge/main.swift`, replace lines 24-29:

```swift
    // Inject environment (our precise-jump key + terminal context).
    let env = ProcessInfo.processInfo.environment
    var envOut: [String: Any] = [:]
    if let iterm = env["ITERM_SESSION_ID"] { envOut["ITERM_SESSION_ID"] = iterm }
    if let tp = env["TERM_PROGRAM"] { envOut["TERM_PROGRAM"] = tp }
    envOut["PID"] = String(ProcessInfo.processInfo.processIdentifier)
    payload["env"] = envOut
```

with the data-driven allowlist:

```swift
    // Inject environment: forward only the curated allowlist the identifiers declare
    // (never the whole environment — env vars routinely hold secrets), plus our PID.
    let env = ProcessInfo.processInfo.environment
    var envOut: [String: Any] = [:]
    for key in TerminalIdentifierRegistry.default.allEnvKeys {
        if let value = env[key] { envOut[key] = value }
    }
    envOut["PID"] = String(ProcessInfo.processInfo.processIdentifier)
    payload["env"] = envOut
```

- [ ] **Step 2: Build and test**

Run: `swift build`
Expected: compiles (the `notch-bridge` executable links against Core).

Run: `swift test`
Expected: PASS (Core suite unaffected).

- [ ] **Step 3: Commit**

```bash
git add Sources/notch-bridge/main.swift
git commit -m "$(cat <<'EOF'
feat: forward a data-driven env allowlist from notch-bridge

Bridge now forwards TerminalIdentifierRegistry.default.allEnvKeys (+ PID)
instead of three hardcoded vars, so new terminals' env vars flow through
with no bridge edit. Still an allowlist, never the whole environment.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Remove `HookEnv` compatibility shims (cleanup)

Drop the iTerm-specific shim init and `itermSessionID` accessor now that identifiers read `values` directly, and migrate the remaining test constructions to `HookEnv(values:)`. Keeps `termProgram` (a cross-terminal standard var). Fulfils the spec's "no per-terminal fields" goal.

**Files:**
- Modify: `Sources/ClaudeNotchCore/Model/HookEvent.swift` (remove shim init + `itermSessionID`)
- Modify: `Tests/ClaudeNotchCoreTests/HookEventTests.swift` (read `values[...]`)
- Modify: `Tests/ClaudeNotchCoreTests/SessionStoreTests.swift` (construct via `values`)
- Modify: `Tests/ClaudeNotchCoreTests/DecisionTests.swift` (construct via `values`)

**Interfaces:**
- Consumes: `HookEnv(values:pid:)` (Task 1). Removes: `HookEnv(itermSessionID:…)`, `HookEnv.itermSessionID`.

- [ ] **Step 1: Remove the shims**

In `Sources/ClaudeNotchCore/Model/HookEvent.swift`, delete the compatibility block from the `HookEnv` struct (the `init(itermSessionID:termProgram:pid:)` and the `var itermSessionID`), leaving `values`, `pid`, `init(values:pid:)`, and `var termProgram`.

- [ ] **Step 2: Migrate `HookEventTests`**

In `Tests/ClaudeNotchCoreTests/HookEventTests.swift`, change the two env assertions in `testDecodesCoreFieldsAndIgnoresUnknown` (lines 20-21):

```swift
        XCTAssertEqual(e.env.values["ITERM_SESSION_ID"], "w0t1p0:UUID-1")
        XCTAssertEqual(e.env.termProgram, "iTerm.app")
```

and in `testMatcherAndMissingEnvTolerated` (line 28) change the nil check:

```swift
        XCTAssertNil(e.env.values["ITERM_SESSION_ID"])
```

- [ ] **Step 3: Migrate `SessionStoreTests`**

In `Tests/ClaudeNotchCoreTests/SessionStoreTests.swift`, change the `event` helper's env argument (line 13) so it builds the bag from the optional `iterm` string:

```swift
                  env: HookEnv(values: iterm.map { ["ITERM_SESSION_ID": $0] } ?? [:]), receivedAt: at())
```

- [ ] **Step 4: Migrate `DecisionTests`**

In `Tests/ClaudeNotchCoreTests/DecisionTests.swift`, change the env in the `event` helper (line 9):

```swift
                         env: HookEnv(values: ["ITERM_SESSION_ID": "w0t1p0:UUID-1"]), toolInput: data,
```

(The `HookEnv()` empty construction on line 30 is unchanged — the no-arg init remains.)

- [ ] **Step 5: Build and test**

Run: `swift build`
Expected: compiles — no remaining references to `itermSessionID`.

Run: `swift test`
Expected: PASS.

- [ ] **Step 6: Verify no shim references remain**

Run: `grep -rn "itermSessionID" Sources Tests`
Expected: no output.

- [ ] **Step 7: Commit**

```bash
git add Sources/ClaudeNotchCore/Model/HookEvent.swift \
        Tests/ClaudeNotchCoreTests/HookEventTests.swift \
        Tests/ClaudeNotchCoreTests/SessionStoreTests.swift \
        Tests/ClaudeNotchCoreTests/DecisionTests.swift
git commit -m "$(cat <<'EOF'
refactor: drop HookEnv iTerm-specific compatibility shims

Remove init(itermSessionID:) and the itermSessionID accessor; identifiers
read env.values directly. HookEnv is now fully terminal-agnostic.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Manual verification (real terminals)

No code. Verify the feature end-to-end and confirm graceful degradation. Requires a debug build running with hooks installed.

- [ ] **Step 1: Build the app**

Run: `swift build`
Expected: all targets compile.

- [ ] **Step 2: iTerm2 regression**

Launch the app, start a Claude Code session in iTerm2, trigger an attention state, click the notch row. Expected: focus lands on the exact iTerm2 window/tab/split (unchanged from before this work).

- [ ] **Step 3: WezTerm precise jump**

Start a Claude Code session in WezTerm (multiple panes open). Click the notch row. Expected: WezTerm comes forward and the correct pane is activated. Confirm `wezterm` is on one of the resolved paths (`/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`).

- [ ] **Step 4: Kitty precise jump**

With Kitty remote control enabled (`allow_remote_control yes` + a listen socket), start a session in Kitty (multiple OS windows). Click the row. Expected: the matching Kitty window is focused and raised.

- [ ] **Step 5: Degradation checks**

(a) Disable Kitty remote control (or test in Ghostty/Terminal.app) → clicking still raises the app (no error notice, `.fellBack`). (b) Quit the target terminal entirely, then click a stale row → expect the "couldn't focus" notice + error sound (`.failed`). (c) Confirm session grouping/keying is stable across events in WezTerm/Kitty (one row per session, not duplicates).

- [ ] **Step 6: Confirm env forwarding**

With a WezTerm and a Kitty session active, confirm identities resolve correctly (rows jump precisely) — this exercises the data-driven bridge allowlist forwarding `WEZTERM_PANE`/`KITTY_WINDOW_ID`.

---

## Self-Review

**1. Spec coverage:**
- §1/§14 extension recipe (add terminal = 3 additive edits, zero switch) → Tasks 2 (identifier), 3 (seam), 4/5 (adapters); the registries have no switches. ✓
- §2 in-scope: two-concern seam (T2/T3), two registries (T2/T3), generic `TerminalIdentity` (T3), generic `HookEnv` + data-driven allowlist (T1/T6), WezTerm+Kitty (T4/T5), seam tests (T2/T3). ✓
- §2 out-of-scope: no Codex, tmux, Terminal.app/Ghostty adapters, no Kitty hint. ✓ (none added)
- §4 decisions: identity/jump split (T2/T3), two real registries (T2/T3), identity-always-resolves (T2 `resolve` total), curated allowlist (T6), keying preserved (T2/T3), CLI avoids TCC (T4/T5 subprocess). ✓
- §8 keying = handle ?? sessionID → `SessionKey.derive(identity:)` (T2), preserved in `SessionStore`/`DecisionRequest.from` (T3). ✓
- §9 degrade chain → `TerminalJumperRegistry.jump` (T3) + adapters (T4/T5). ✓
- §10 testing (update existing + 3 seam groups) → T2/T3 tests; no extra new tests. ✓
- §11 error/edge (CLI missing, remote control off, timeout, $TMUX, unknown, no app) → T4/T5 `.failed` paths + registry fallback; $TMUX/unknown → generic identifier. ✓
- §12 security (allowlist, argv array, no shell) → T6 allowlist, T4 `Process` argv. ✓
- §13 build sequence maps onto T1–T8. ✓

**2. Placeholder scan:** No TBD/TODO/"handle edge cases"/"similar to". Every code step shows complete code. ✓

**3. Type consistency:** `TerminalIdentity(adapterID:handle:appName:pid:)`, `TerminalIdentifying.identify(_:)`, `TerminalIdentifierRegistry.resolve/key/allEnvKeys/.default`, `SessionKey.derive(identity:sessionID:)`, `TerminalJumping.jump(to:)`/`adapterID`, `TerminalJumperRegistry.init(adapters:fallback:)`/`jump(to:)`, `TerminalShell.resolve/run/raiseApp`, adapterIDs `"iterm2"/"wezterm"/"kitty"/"generic"` — used identically across tasks. ✓
