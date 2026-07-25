# ClaudeNotch v2 — Act-in-place (Permission + Plan) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a blocked Claude Code session's tool-permission and plan-approval decisions be made from the notch (Allow/Deny, Approve/Request-changes), returning the decision synchronously to the waiting session.

**Architecture:** A synchronous `PermissionRequest` hook runs `notch-bridge decide`, which POSTs to the app over v1's loopback HTTP + token and **blocks reading the response**. The app parses a `DecisionRequest`, surfaces a decision card in the notch, and — when the user clicks — writes the decision JSON back as the HTTP response body; the helper prints it to stdout so Claude Code applies `allow`/`deny`. Every failure path returns an empty body → the helper prints nothing → Claude shows its normal terminal prompt (passthrough). Pure logic lives in `ClaudeNotchCore` (unit-tested); transport/UI/helper wiring lives in the app + helper targets (manual verification).

**Tech Stack:** Swift 6 (language mode v5), macOS 14+, SwiftPM, AppKit + SwiftUI, DynamicNotchKit, Network.framework, XCTest.

## Global Constraints

- **Repo:** local git only — no remote, no push. **No JIRA** — commit messages are `type: summary` (Conventional Commits), and **every commit message ends with the trailer** `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Branch:** all work on `feat/claudenotch-v2-act-in-place` (created in Task 0), cut from `main` (`3252fd9`).
- **Never degrade Claude Code:** every decision-path failure (app down, timeout, malformed, crash, "answer in terminal") resolves to **passthrough** = empty HTTP body → helper prints nothing → normal terminal prompt. Never a hang, never a silent auto-allow.
- **Feature floor:** act-in-place hooks are installed only when `claude --version` ≥ **2.1.200**; otherwise the app runs as the v1 monitor.
- **Security:** HTTP stays 127.0.0.1-only; `/decide` is token-gated exactly like `/hook`. Remembered "allow-for-session" approvals are **in-memory only, never written to disk**.
- **Wire contract (verbatim):** allow → `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}`; deny → same with `"behavior":"deny","message":<reason>`; passthrough → emit nothing.
- **Module rules:** pure, AppKit-free, Network-free types go in `ClaudeNotchCore` and get XCTest coverage. `ClaudeNotchApp`/`notch-bridge` have no test target — verify them manually with the documented commands.
- **Style:** match v1 — `JSONSerialization` (not Codable) for arbitrary Claude JSON; the ownership sentinel for our hooks is the quoted-helper-path prefix on the `command` string; value types use synthesized memberwise inits.
- **Testing policy:** implement exactly the tests this plan specifies. No speculative/extra tests.
- **Verify each task:** `swift build` must be 0 warnings and `swift test` green before every commit.

---

## File Structure

**New (ClaudeNotchCore — pure, tested):**
- `Sources/ClaudeNotchCore/Model/ToolPreview.swift` — `ToolPreview`, `DiffLine` value types for rendering a permission payload.
- `Sources/ClaudeNotchCore/Model/Decision.swift` — `AllowScope`, `Decision`, `DecisionKind`, `DecisionRequest` (+ `DecisionRequest.from`).
- `Sources/ClaudeNotchCore/Model/SessionKey.swift` — shared session-key derivation.
- `Sources/ClaudeNotchCore/Domain/ToolInputRenderer.swift` — `tool_input` → `ToolPreview`.
- `Sources/ClaudeNotchCore/Domain/DecisionEncoder.swift` — `Decision` → stdout JSON.
- `Sources/ClaudeNotchCore/Domain/RememberedDecisions.swift` — in-memory allow-for-session store.
- `Sources/ClaudeNotchCore/Domain/DecisionBroker.swift` — actor holding in-flight decisions + timeout.
- `Sources/ClaudeNotchCore/Install/ClaudeVersion.swift` — version string parse + `meetsMinimum`.

**Modified (ClaudeNotchCore):**
- `Model/HookEvent.swift` — capture `tool_input` (as `Data?`) + `toolInputDict`.
- `Domain/SessionStore.swift` — use `SessionKey.derive` (DRY; no behavior change).
- `Install/HookInstaller.swift` — per-spec `async`/`timeout`; optional `PermissionRequest` specs.

**Modified (ClaudeNotchApp / notch-bridge — manual verification):**
- `Transport/HookServer.swift` — `POST /decide/<event>` held-open endpoint + `onDecision` callback.
- `Sources/notch-bridge/main.swift` — `decide` mode (block on response, print body, passthrough on failure).
- `UI/NotchViews.swift` — decision state + `PermissionCard` + `PlanCard`.
- `UI/NotchController.swift` — `update(pending:)`, auto-`expand()`, `onDecide`.
- `AppCoordinator.swift` — wire `DecisionBroker`, `RememberedDecisions`, `onDecision`, version-gated install.

**New tests (ClaudeNotchCoreTests):**
`ToolInputRendererTests`, `DecisionTests`, `DecisionEncoderTests`, `RememberedDecisionsTests`, `DecisionBrokerTests`, `ClaudeVersionTests`; extend `HookEventTests`, `HookInstallerTests`.

---

### Task 0: Branch

- [ ] **Step 1: Create the feature branch**

```bash
cd /Users/navjotdhanawat/Workspace/claude-notch
git checkout main && git checkout -b feat/claudenotch-v2-act-in-place
git branch --show-current   # expect: feat/claudenotch-v2-act-in-place
```

---

### Task 1: Capture `tool_input` on HookEvent + shared session key

**Files:**
- Modify: `Sources/ClaudeNotchCore/Model/HookEvent.swift`
- Create: `Sources/ClaudeNotchCore/Model/SessionKey.swift`
- Modify: `Sources/ClaudeNotchCore/Domain/SessionStore.swift` (use `SessionKey.derive`)
- Test: `Tests/ClaudeNotchCoreTests/HookEventTests.swift` (extend)

**Interfaces:**
- Produces: `HookEvent.toolInput: Data?`, `HookEvent.toolInputDict: [String: Any]?`, `SessionKey.derive(env:sessionID:) -> String`.
- Consumes: existing `HookEvent`, `HookEnv`, `TerminalRef.itermUUID(from:)`.

- [ ] **Step 1: Write the failing test** (append to `HookEventTests.swift`)

```swift
func testDecodeCapturesToolInput() throws {
    let json = """
    {"session_id":"s1","cwd":"/w","tool_name":"Edit",
     "tool_input":{"file_path":"a.ts","old_string":"x","new_string":"y"}}
    """
    let e = try HookEvent.decode(Data(json.utf8), name: .permissionRequest, now: Date(timeIntervalSince1970: 100))
    XCTAssertEqual(e.toolName, "Edit")
    let dict = e.toolInputDict
    XCTAssertEqual(dict?["file_path"] as? String, "a.ts")
    XCTAssertEqual(dict?["new_string"] as? String, "y")
}

func testDecodeToolInputAbsentIsNil() throws {
    let e = try HookEvent.decode(Data(#"{"session_id":"s1"}"#.utf8), name: .stop, now: Date(timeIntervalSince1970: 100))
    XCTAssertNil(e.toolInput)
    XCTAssertNil(e.toolInputDict)
}

func testSessionKeyPrefersItermUUID() {
    XCTAssertEqual(SessionKey.derive(env: HookEnv(itermSessionID: "w0t1p0:UUID-9"), sessionID: "s1"), "UUID-9")
    XCTAssertEqual(SessionKey.derive(env: HookEnv(itermSessionID: nil), sessionID: "s1"), "s1")
    XCTAssertEqual(SessionKey.derive(env: HookEnv(itermSessionID: ""), sessionID: "s1"), "s1")
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter HookEventTests`
Expected: FAIL — `toolInput`/`toolInputDict`/`SessionKey` unresolved.

- [ ] **Step 3: Create `SessionKey.swift`**

```swift
import Foundation

/// Single source of truth for a session's stable key: the iTerm UUID suffix when
/// present, else the Claude session id. Shared by SessionStore and the decision path.
public enum SessionKey {
    public static func derive(env: HookEnv, sessionID: String) -> String {
        if let iterm = env.itermSessionID, !iterm.isEmpty {
            return TerminalRef.itermUUID(from: iterm)
        }
        return sessionID
    }
}
```

- [ ] **Step 4: Add `toolInput` to `HookEvent`** (edit `HookEvent.swift`)

Add stored property to the struct (keeps `Sendable`/`Equatable` because `Data` conforms):

```swift
    public let env: HookEnv
    public let toolInput: Data?          // raw JSON of tool_input, or nil
    public let receivedAt: Date
```

Update the memberwise `init` to include `toolInput: Data? = nil` (place the parameter immediately before `receivedAt`). Add the computed accessor:

```swift
    /// Parsed tool_input object, or nil if absent/malformed.
    public var toolInputDict: [String: Any]? {
        guard let toolInput else { return nil }
        return (try? JSONSerialization.jsonObject(with: toolInput)) as? [String: Any]
    }
```

In `decode`, after the existing field extraction, capture the raw `tool_input` object:

```swift
        var toolInputData: Data? = nil
        if let ti = obj["tool_input"] {
            toolInputData = try? JSONSerialization.data(withJSONObject: ti)
        }
```

and pass `toolInput: toolInputData` into the `HookEvent(...)` constructed at the end of `decode`.

- [ ] **Step 5: DRY `SessionStore.key(for:)`** (edit `SessionStore.swift`)

Replace the body of the private `key(for:)` with the shared helper (behavior identical):

```swift
    private func key(for event: HookEvent) -> String {
        SessionKey.derive(env: event.env, sessionID: event.sessionID)
    }
```

- [ ] **Step 6: Run tests**

Run: `swift test --filter HookEventTests` then `swift test`
Expected: PASS (all existing SessionStore tests still green — key derivation unchanged).

- [ ] **Step 7: Commit**

```bash
git add Sources/ClaudeNotchCore Tests/ClaudeNotchCoreTests/HookEventTests.swift
git commit -m "feat: capture tool_input on HookEvent and share session-key derivation" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: ToolPreview + ToolInputRenderer

**Files:**
- Create: `Sources/ClaudeNotchCore/Model/ToolPreview.swift`
- Create: `Sources/ClaudeNotchCore/Domain/ToolInputRenderer.swift`
- Test: `Tests/ClaudeNotchCoreTests/ToolInputRendererTests.swift`

**Interfaces:**
- Produces: `ToolPreview` (`.diff(file:lines:)` | `.command(String)` | `.raw(String)`), `DiffLine(kind:text:)`, `ToolInputRenderer.render(tool:input:) -> ToolPreview`.
- Consumes: nothing new.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ClaudeNotchCore

final class ToolInputRendererTests: XCTestCase {
    func testEditProducesDiff() {
        let p = ToolInputRenderer.render(tool: "Edit",
            input: ["file_path": "a.ts", "old_string": "let x = 1", "new_string": "let x = 2"])
        guard case let .diff(file, lines) = p else { return XCTFail("expected diff") }
        XCTAssertEqual(file, "a.ts")
        XCTAssertEqual(lines, [DiffLine(kind: .removed, text: "let x = 1"),
                               DiffLine(kind: .added, text: "let x = 2")])
    }

    func testWriteProducesAllAddedDiff() {
        let p = ToolInputRenderer.render(tool: "Write", input: ["file_path": "n.txt", "content": "a\nb"])
        guard case let .diff(file, lines) = p else { return XCTFail("expected diff") }
        XCTAssertEqual(file, "n.txt")
        XCTAssertEqual(lines, [DiffLine(kind: .added, text: "a"), DiffLine(kind: .added, text: "b")])
    }

    func testBashProducesCommand() {
        let p = ToolInputRenderer.render(tool: "Bash", input: ["command": "rm -rf build"])
        XCTAssertEqual(p, .command("rm -rf build"))
    }

    func testUnknownToolFallsBackToRaw() {
        let p = ToolInputRenderer.render(tool: "Grep", input: ["pattern": "foo"])
        guard case .raw = p else { return XCTFail("expected raw") }
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter ToolInputRendererTests`
Expected: FAIL — `ToolPreview`/`ToolInputRenderer` unresolved.

- [ ] **Step 3: Create `ToolPreview.swift`**

```swift
import Foundation

public struct DiffLine: Sendable, Equatable {
    public enum Kind: Sendable, Equatable { case context, added, removed }
    public let kind: Kind
    public let text: String
    public init(kind: Kind, text: String) { self.kind = kind; self.text = text }
}

/// A renderable view of a tool's proposed action for a permission card.
public enum ToolPreview: Sendable, Equatable {
    case diff(file: String, lines: [DiffLine])   // Edit / MultiEdit / Write
    case command(String)                          // Bash
    case raw(String)                              // anything else
}
```

- [ ] **Step 4: Create `ToolInputRenderer.swift`**

```swift
import Foundation

public enum ToolInputRenderer {
    public static func render(tool: String, input: [String: Any]) -> ToolPreview {
        switch tool {
        case "Edit":
            let file = (input["file_path"] as? String) ?? ""
            let removed = splitLines(input["old_string"] as? String).map { DiffLine(kind: .removed, text: $0) }
            let added = splitLines(input["new_string"] as? String).map { DiffLine(kind: .added, text: $0) }
            return .diff(file: file, lines: removed + added)
        case "MultiEdit":
            let file = (input["file_path"] as? String) ?? ""
            var lines: [DiffLine] = []
            for edit in (input["edits"] as? [[String: Any]]) ?? [] {
                lines += splitLines(edit["old_string"] as? String).map { DiffLine(kind: .removed, text: $0) }
                lines += splitLines(edit["new_string"] as? String).map { DiffLine(kind: .added, text: $0) }
            }
            return .diff(file: file, lines: lines)
        case "Write":
            let file = (input["file_path"] as? String) ?? ""
            return .diff(file: file, lines: splitLines(input["content"] as? String).map { DiffLine(kind: .added, text: $0) })
        case "Bash":
            return .command((input["command"] as? String) ?? "")
        default:
            let name = (input["file_path"] as? String) ?? (input["command"] as? String) ?? tool
            return .raw(name)
        }
    }

    private static func splitLines(_ s: String?) -> [String] {
        guard let s, !s.isEmpty else { return [] }
        return s.components(separatedBy: "\n")
    }
}
```

- [ ] **Step 5: Run tests**

Run: `swift test --filter ToolInputRendererTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/ClaudeNotchCore Tests/ClaudeNotchCoreTests/ToolInputRendererTests.swift
git commit -m "feat: add ToolPreview and ToolInputRenderer for permission cards" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Decision types + DecisionRequest.from

**Files:**
- Create: `Sources/ClaudeNotchCore/Model/Decision.swift`
- Test: `Tests/ClaudeNotchCoreTests/DecisionTests.swift`

**Interfaces:**
- Produces: `AllowScope` (`.once`/`.session`); `Decision` (`.allow(scope:)`/`.deny(reason:)`/`.passthrough`); `DecisionKind` (`.toolPermission(tool:preview:)`/`.planApproval(text:)`); `DecisionRequest(id:sessionKey:kind:receivedAt:)`; `DecisionRequest.from(_ event: HookEvent, id: String) -> DecisionRequest?`.
- Consumes: `HookEvent`, `SessionKey.derive`, `ToolInputRenderer.render`, `ToolPreview`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ClaudeNotchCore

final class DecisionTests: XCTestCase {
    private func event(tool: String, input: [String: Any]) -> HookEvent {
        let data = try! JSONSerialization.data(withJSONObject: input)
        return HookEvent(name: .permissionRequest, sessionID: "s1", cwd: "/w", matcher: "*",
                         toolName: tool, transcriptPath: nil,
                         env: HookEnv(itermSessionID: "w0t1p0:UUID-1"), toolInput: data,
                         receivedAt: Date(timeIntervalSince1970: 5))
    }

    func testFromEditIsToolPermission() {
        let req = DecisionRequest.from(event(tool: "Edit",
            input: ["file_path": "a.ts", "old_string": "x", "new_string": "y"]), id: "r1")
        XCTAssertEqual(req?.sessionKey, "UUID-1")
        guard case let .toolPermission(tool, preview)? = req?.kind else { return XCTFail() }
        XCTAssertEqual(tool, "Edit")
        guard case .diff = preview else { return XCTFail("expected diff preview") }
    }

    func testFromExitPlanModeIsPlanApproval() {
        let req = DecisionRequest.from(event(tool: "ExitPlanMode", input: ["plan": "1. do X\n2. do Y"]), id: "r2")
        guard case let .planApproval(text)? = req?.kind else { return XCTFail() }
        XCTAssertEqual(text, "1. do X\n2. do Y")
    }

    func testFromWithoutToolNameIsNil() {
        let e = HookEvent(name: .permissionRequest, sessionID: "s1", cwd: "/w", matcher: nil,
                          toolName: nil, transcriptPath: nil, env: HookEnv(), toolInput: nil,
                          receivedAt: Date(timeIntervalSince1970: 5))
        XCTAssertNil(DecisionRequest.from(e, id: "r3"))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter DecisionTests`
Expected: FAIL — `Decision`/`DecisionRequest` unresolved.

- [ ] **Step 3: Create `Decision.swift`**

```swift
import Foundation

public enum AllowScope: Sendable, Equatable { case once, session }

public enum Decision: Sendable, Equatable {
    case allow(scope: AllowScope)
    case deny(reason: String?)
    case passthrough
}

public enum DecisionKind: Sendable, Equatable {
    case toolPermission(tool: String, preview: ToolPreview)
    case planApproval(text: String)
}

public struct DecisionRequest: Identifiable, Sendable, Equatable {
    public let id: String
    public let sessionKey: String
    public let kind: DecisionKind
    public let receivedAt: Date
    public init(id: String, sessionKey: String, kind: DecisionKind, receivedAt: Date) {
        self.id = id; self.sessionKey = sessionKey; self.kind = kind; self.receivedAt = receivedAt
    }
}

public extension DecisionRequest {
    /// Build a DecisionRequest from a decoded PermissionRequest event. Returns nil if there is no tool.
    static func from(_ event: HookEvent, id: String) -> DecisionRequest? {
        guard let tool = event.toolName else { return nil }
        let sessionKey = SessionKey.derive(env: event.env, sessionID: event.sessionID)
        let input = event.toolInputDict ?? [:]
        let kind: DecisionKind
        if tool == "ExitPlanMode" {
            kind = .planApproval(text: (input["plan"] as? String) ?? "")
        } else {
            kind = .toolPermission(tool: tool, preview: ToolInputRenderer.render(tool: tool, input: input))
        }
        return DecisionRequest(id: id, sessionKey: sessionKey, kind: kind, receivedAt: event.receivedAt)
    }
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter DecisionTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchCore/Model/Decision.swift Tests/ClaudeNotchCoreTests/DecisionTests.swift
git commit -m "feat: add Decision domain types and DecisionRequest.from" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: DecisionEncoder (wire contract)

**Files:**
- Create: `Sources/ClaudeNotchCore/Domain/DecisionEncoder.swift`
- Test: `Tests/ClaudeNotchCoreTests/DecisionEncoderTests.swift`

**Interfaces:**
- Produces: `DecisionEncoder.stdoutJSON(for: Decision) -> Data?` (nil for `.passthrough`).
- Consumes: `Decision`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ClaudeNotchCore

final class DecisionEncoderTests: XCTestCase {
    private func obj(_ data: Data) -> [String: Any] {
        (try! JSONSerialization.jsonObject(with: data)) as! [String: Any]
    }

    func testAllowShape() {
        let d = DecisionEncoder.stdoutJSON(for: .allow(scope: .once))!
        let hs = obj(d)["hookSpecificOutput"] as! [String: Any]
        XCTAssertEqual(hs["hookEventName"] as? String, "PermissionRequest")
        XCTAssertEqual((hs["decision"] as! [String: Any])["behavior"] as? String, "allow")
    }

    func testDenyIncludesMessage() {
        let d = DecisionEncoder.stdoutJSON(for: .deny(reason: "nope"))!
        let dec = (obj(d)["hookSpecificOutput"] as! [String: Any])["decision"] as! [String: Any]
        XCTAssertEqual(dec["behavior"] as? String, "deny")
        XCTAssertEqual(dec["message"] as? String, "nope")
    }

    func testDenyDefaultMessageWhenNil() {
        let d = DecisionEncoder.stdoutJSON(for: .deny(reason: nil))!
        let dec = (obj(d)["hookSpecificOutput"] as! [String: Any])["decision"] as! [String: Any]
        XCTAssertEqual(dec["behavior"] as? String, "deny")
        XCTAssertNotNil(dec["message"] as? String)
    }

    func testPassthroughIsNil() {
        XCTAssertNil(DecisionEncoder.stdoutJSON(for: .passthrough))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter DecisionEncoderTests`
Expected: FAIL — `DecisionEncoder` unresolved.

- [ ] **Step 3: Create `DecisionEncoder.swift`**

```swift
import Foundation

/// Encodes a Decision into the exact `PermissionRequest` hook stdout contract.
/// Returns nil for `.passthrough` — the caller must then emit NOTHING so Claude
/// Code shows its normal permission dialog.
public enum DecisionEncoder {
    public static func stdoutJSON(for decision: Decision) -> Data? {
        let behavior: [String: Any]
        switch decision {
        case .allow:
            behavior = ["behavior": "allow"]
        case .deny(let reason):
            behavior = ["behavior": "deny", "message": reason ?? "Denied from ClaudeNotch"]
        case .passthrough:
            return nil
        }
        let root: [String: Any] = [
            "hookSpecificOutput": [
                "hookEventName": "PermissionRequest",
                "decision": behavior
            ]
        ]
        return try? JSONSerialization.data(withJSONObject: root)
    }
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter DecisionEncoderTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchCore/Domain/DecisionEncoder.swift Tests/ClaudeNotchCoreTests/DecisionEncoderTests.swift
git commit -m "feat: add DecisionEncoder for PermissionRequest stdout contract" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: RememberedDecisions (allow-for-session)

**Files:**
- Create: `Sources/ClaudeNotchCore/Domain/RememberedDecisions.swift`
- Test: `Tests/ClaudeNotchCoreTests/RememberedDecisionsTests.swift`

**Interfaces:**
- Produces: `RememberedDecisions()`, `.remember(sessionKey:tool:)`, `.isAllowed(sessionKey:tool:) -> Bool`, `.clear(sessionKey:)`, `.clearAll()`.
- Consumes: nothing.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ClaudeNotchCore

final class RememberedDecisionsTests: XCTestCase {
    func testRememberThenAllowedForSameSessionAndTool() {
        let r = RememberedDecisions()
        XCTAssertFalse(r.isAllowed(sessionKey: "S", tool: "Bash"))
        r.remember(sessionKey: "S", tool: "Bash")
        XCTAssertTrue(r.isAllowed(sessionKey: "S", tool: "Bash"))
        XCTAssertFalse(r.isAllowed(sessionKey: "S", tool: "Edit"))   // scoped per tool
        XCTAssertFalse(r.isAllowed(sessionKey: "T", tool: "Bash"))   // scoped per session
    }

    func testClearSession() {
        let r = RememberedDecisions()
        r.remember(sessionKey: "S", tool: "Bash")
        r.clear(sessionKey: "S")
        XCTAssertFalse(r.isAllowed(sessionKey: "S", tool: "Bash"))
    }

    func testClearAll() {
        let r = RememberedDecisions()
        r.remember(sessionKey: "S", tool: "Bash")
        r.remember(sessionKey: "T", tool: "Edit")
        r.clearAll()
        XCTAssertFalse(r.isAllowed(sessionKey: "S", tool: "Bash"))
        XCTAssertFalse(r.isAllowed(sessionKey: "T", tool: "Edit"))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter RememberedDecisionsTests`
Expected: FAIL — `RememberedDecisions` unresolved.

- [ ] **Step 3: Create `RememberedDecisions.swift`**

```swift
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
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter RememberedDecisionsTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchCore/Domain/RememberedDecisions.swift Tests/ClaudeNotchCoreTests/RememberedDecisionsTests.swift
git commit -m "feat: add in-memory RememberedDecisions store for allow-for-session" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: DecisionBroker (in-flight decisions + timeout)

**Files:**
- Create: `Sources/ClaudeNotchCore/Domain/DecisionBroker.swift`
- Test: `Tests/ClaudeNotchCoreTests/DecisionBrokerTests.swift`

**Interfaces:**
- Produces: `actor DecisionBroker`, `init(timeout: TimeInterval)`, `func decide(_ request: DecisionRequest) async -> Decision`, `func resolve(id: String, _ decision: Decision)`, `func setOnPendingChanged(_ cb: @escaping @Sendable ([DecisionRequest]) -> Void)`, `func snapshotPending() -> [DecisionRequest]`.
- Consumes: `DecisionRequest`, `Decision`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ClaudeNotchCore

final class DecisionBrokerTests: XCTestCase {
    private func req(_ id: String) -> DecisionRequest {
        DecisionRequest(id: id, sessionKey: "S", kind: .planApproval(text: "p"),
                        receivedAt: Date(timeIntervalSince1970: 1))
    }

    func testResolveReturnsDecision() async {
        let broker = DecisionBroker(timeout: 100)
        async let decided = broker.decide(req("r1"))
        try? await Task.sleep(nanoseconds: 20_000_000)  // let decide register
        await broker.resolve(id: "r1", .allow(scope: .session))
        let got = await decided
        XCTAssertEqual(got, .allow(scope: .session))
    }

    func testTimeoutReturnsPassthrough() async {
        let broker = DecisionBroker(timeout: 0.05)
        let got = await broker.decide(req("r2"))
        XCTAssertEqual(got, .passthrough)
    }

    func testPendingReflectsInFlight() async {
        let broker = DecisionBroker(timeout: 100)
        async let decided = broker.decide(req("r3"))
        try? await Task.sleep(nanoseconds: 20_000_000)
        let pending = await broker.snapshotPending()
        XCTAssertEqual(pending.map(\.id), ["r3"])
        await broker.resolve(id: "r3", .deny(reason: nil))
        _ = await decided
        let after = await broker.snapshotPending()
        XCTAssertTrue(after.isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter DecisionBrokerTests`
Expected: FAIL — `DecisionBroker` unresolved.

- [ ] **Step 3: Create `DecisionBroker.swift`**

```swift
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
        // Arm the timeout; if still pending when it fires, resolve to passthrough.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.timeout ?? 0 * 1_000_000_000))
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
```

> Note on the timeout `Task`: write the sleep as `UInt64(self.timeout * 1_000_000_000)` — compute the product inside the actor. If Swift's optional-chaining precedence trips the expression, capture `let t = self?.timeout ?? 0` first, then `Task.sleep(nanoseconds: UInt64(t * 1_000_000_000))`.

- [ ] **Step 4: Fix the timeout expression** (edit the `Task` in `decide`)

```swift
        Task { [weak self] in
            guard let self else { return }
            let t = await self.timeout
            try? await Task.sleep(nanoseconds: UInt64(t * 1_000_000_000))
            await self.resolve(id: id, .passthrough)
        }
```

- [ ] **Step 5: Run tests**

Run: `swift test --filter DecisionBrokerTests`
Expected: PASS (timeout test completes in ~50 ms; resolve/pending tests pass).

- [ ] **Step 6: Commit**

```bash
git add Sources/ClaudeNotchCore/Domain/DecisionBroker.swift Tests/ClaudeNotchCoreTests/DecisionBrokerTests.swift
git commit -m "feat: add DecisionBroker actor with resolve and timeout-to-passthrough" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: HookInstaller — per-spec async/timeout, version detect, PermissionRequest specs

**Files:**
- Create: `Sources/ClaudeNotchCore/Install/ClaudeVersion.swift`
- Modify: `Sources/ClaudeNotchCore/Install/HookInstaller.swift`
- Test: `Tests/ClaudeNotchCoreTests/ClaudeVersionTests.swift` (new), `Tests/ClaudeNotchCoreTests/HookInstallerTests.swift` (extend)

**Interfaces:**
- Produces: `ClaudeVersion.parse(_:) -> (Int,Int,Int)?`, `ClaudeVersion.meetsMinimum(_:_ :) -> Bool`; `HookInstaller(helperPath:decisionsEnabled:)`.
- Consumes: existing `HookInstaller` merge/save internals.

- [ ] **Step 1: Write failing tests**

`ClaudeVersionTests.swift`:
```swift
import XCTest
@testable import ClaudeNotchCore

final class ClaudeVersionTests: XCTestCase {
    func testParsesVersionFromClaudeOutput() {
        XCTAssertEqual(ClaudeVersion.parse("2.1.217 (Claude Code)")!.0, 2)
        XCTAssertEqual(ClaudeVersion.parse("2.1.217 (Claude Code)")!.2, 217)
    }
    func testMeetsMinimum() {
        XCTAssertTrue(ClaudeVersion.meetsMinimum("2.1.217 (Claude Code)", (2, 1, 200)))
        XCTAssertFalse(ClaudeVersion.meetsMinimum("2.1.199", (2, 1, 200)))
        XCTAssertTrue(ClaudeVersion.meetsMinimum("2.2.0", (2, 1, 200)))
        XCTAssertFalse(ClaudeVersion.meetsMinimum("garbage", (2, 1, 200)))
    }
}
```

Append to `HookInstallerTests.swift`:
```swift
func testPermissionRequestInstalledWhenDecisionsEnabled() throws {
    let url = tmpURL()
    defer { remove(url) }
    try HookInstaller(helperPath: "/App/notch-bridge", decisionsEnabled: true).install(into: url)
    let root = try read(url)
    let hooks = root["hooks"] as! [String: Any]
    let pr = hooks["PermissionRequest"] as! [[String: Any]]
    let matchers = pr.compactMap { $0["matcher"] as? String }.sorted()
    XCTAssertEqual(matchers, ["*", "ExitPlanMode"])
    // synchronous: our decision hooks must NOT be async:true and must carry a timeout
    for group in pr {
        let inner = (group["hooks"] as! [[String: Any]]).first { ($0["command"] as? String)?.hasPrefix("\"/App/notch-bridge\"") == true }!
        XCTAssertNil(inner["async"])
        XCTAssertEqual(inner["timeout"] as? Int, 600)
        XCTAssertEqual(inner["command"] as? String, group["matcher"] as? String == "ExitPlanMode"
            ? "\"/App/notch-bridge\" decide PermissionRequest"
            : "\"/App/notch-bridge\" decide PermissionRequest")
    }
}

func testPermissionRequestOmittedWhenDecisionsDisabled() throws {
    let url = tmpURL()
    defer { remove(url) }
    try HookInstaller(helperPath: "/App/notch-bridge", decisionsEnabled: false).install(into: url)
    let hooks = try read(url)["hooks"] as! [String: Any]
    XCTAssertNil(hooks["PermissionRequest"])
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter ClaudeVersionTests` then `swift test --filter HookInstallerTests`
Expected: FAIL — `ClaudeVersion` unresolved; `decisionsEnabled:` label unknown.

- [ ] **Step 3: Create `ClaudeVersion.swift`**

```swift
import Foundation

public enum ClaudeVersion {
    /// Parses the leading semver from `claude --version` output, e.g. "2.1.217 (Claude Code)".
    public static func parse(_ output: String) -> (Int, Int, Int)? {
        let token = output.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ").first.map(String.init) ?? ""
        let parts = token.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 3 else { return nil }
        return (parts[0], parts[1], parts[2])
    }

    public static func meetsMinimum(_ output: String, _ min: (Int, Int, Int)) -> Bool {
        guard let v = parse(output) else { return false }
        if v.0 != min.0 { return v.0 > min.0 }
        if v.1 != min.1 { return v.1 > min.1 }
        return v.2 >= min.2
    }
}
```

- [ ] **Step 4: Modify `HookInstaller.swift`**

Add the init flag and a per-spec async/timeout model. Change the `specs` type and add the extra entries when enabled:

```swift
public struct HookInstaller {
    public let helperPath: String
    public let decisionsEnabled: Bool
    public init(helperPath: String, decisionsEnabled: Bool = false) {
        self.helperPath = helperPath
        self.decisionsEnabled = decisionsEnabled
    }

    private struct Spec { let event: String; let matcher: String; let args: String; let isAsync: Bool; let timeout: Int? }

    private var specs: [Spec] {
        var s: [Spec] = [
            Spec(event: "SessionStart",  matcher: "*", args: "SessionStart", isAsync: true, timeout: nil),
            Spec(event: "PreToolUse",    matcher: "*", args: "PreToolUse",   isAsync: true, timeout: nil),
            Spec(event: "Notification",  matcher: "permission_prompt",
                 args: "Notification permission_prompt", isAsync: true, timeout: nil),
            Spec(event: "Notification",  matcher: "idle_prompt|elicitation_dialog|agent_needs_input",
                 args: "Notification needs_input", isAsync: true, timeout: nil),
            Spec(event: "Stop",          matcher: "*", args: "Stop",         isAsync: true, timeout: nil),
            Spec(event: "StopFailure",   matcher: "*", args: "StopFailure",  isAsync: true, timeout: nil),
            Spec(event: "SessionEnd",    matcher: "*", args: "SessionEnd",   isAsync: true, timeout: nil),
        ]
        if decisionsEnabled {
            s.append(Spec(event: "PermissionRequest", matcher: "*",
                          args: "decide PermissionRequest", isAsync: false, timeout: 600))
            s.append(Spec(event: "PermissionRequest", matcher: "ExitPlanMode",
                          args: "decide PermissionRequest", isAsync: false, timeout: 600))
        }
        return s
    }
```

Update the command builder + hook-dict builder in `install` to use `Spec.args`, `isAsync`, `timeout`:

```swift
    private func command(args: String) -> String { "\"\(helperPath)\" \(args)" }
```

and where a hook dict is built for each spec:

```swift
        var hook: [String: Any] = ["type": "command", "command": command(args: spec.args)]
        if spec.isAsync { hook["async"] = true }
        if let t = spec.timeout { hook["timeout"] = t }
```

Keep `isOurs`/`stripOurs`/`save`/`loadRoot` exactly as-is (sentinel = quoted-path prefix still matches `decide` commands). Iterate `for spec in specs` and group by `spec.event` then `spec.matcher` as before.

- [ ] **Step 5: Run tests**

Run: `swift test --filter ClaudeVersionTests` then `swift test --filter HookInstallerTests` then `swift test`
Expected: PASS. (Existing `testInstallIsIdempotent` still sees exactly 2 `Notification` groups — unaffected.)

- [ ] **Step 6: Commit**

```bash
git add Sources/ClaudeNotchCore/Install Tests/ClaudeNotchCoreTests/ClaudeVersionTests.swift Tests/ClaudeNotchCoreTests/HookInstallerTests.swift
git commit -m "feat: install synchronous PermissionRequest hooks behind a version gate" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: HookServer — held-open `/decide` endpoint

**Files:**
- Modify: `Sources/ClaudeNotchApp/Transport/HookServer.swift`

**Interfaces:**
- Produces: `HookServer(token:onEvent:onDecision:)` where `onDecision: ((HookEvent, @escaping (Decision) -> Void) -> Void)?`.
- Consumes: `DecisionEncoder.stdoutJSON(for:)`, `HookEvent.decode`.

*No unit test (app target has no tests) — verified by the curl smoke in Step 5 and end-to-end in Task 12.*

- [ ] **Step 1: Add the `onDecision` parameter** (edit `init`)

```swift
    public init(token: String,
                onEvent: @escaping (HookEvent) -> Void,
                onDecision: ((HookEvent, @escaping (Decision) -> Void) -> Void)? = nil) {
        self.token = token
        self.onEvent = onEvent
        self.onDecision = onDecision
    }
```
Add stored property: `private let onDecision: ((HookEvent, @escaping (Decision) -> Void) -> Void)?`.

- [ ] **Step 2: Split response writing into a reusable writer** (edit `respond`)

Replace the body of `respond` so it branches on the `/decide/` path prefix and only writes immediately for non-decision paths:

```swift
    private func respond(_ conn: NWConnection, headers: [String], body: Data) {
        let requestLine = headers.first ?? ""
        let path = requestLine.split(separator: " ").dropFirst().first.map(String.init) ?? ""
        let sentToken = headers.first(where: { $0.lowercased().hasPrefix("x-claudenotch-token:") })
            .map { line -> String in
                let p = line.split(separator: ":", maxSplits: 1)
                return p.count > 1 ? p[1].trimmingCharacters(in: .whitespaces) : ""
            }

        guard sentToken == token else { return write(conn, status: "401 Unauthorized", body: Data()) }
        guard let name = Self.eventName(fromPath: path),
              let event = try? HookEvent.decode(body, name: name, now: Date()) else {
            return write(conn, status: "400 Bad Request", body: Data())
        }

        if path.hasPrefix("/decide/"), let onDecision {
            // Hold the connection open until a decision resolves; then write the JSON body.
            onDecision(event) { [weak self] decision in
                let body = DecisionEncoder.stdoutJSON(for: decision) ?? Data()   // passthrough → empty
                self?.write(conn, status: "200 OK", body: body)
            }
        } else {
            onEvent(event)
            write(conn, status: "200 OK", body: Data())
        }
    }

    private func write(_ conn: NWConnection, status: String, body: Data) {
        var data = Data("HTTP/1.1 \(status)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
        data.append(body)
        conn.send(content: data, completion: .contentProcessed { _ in conn.cancel() })
    }
```

- [ ] **Step 3: Recognize `/decide/<Event>` in path routing**

`eventName(fromPath:)` already takes the last `/`-segment, so `/decide/PermissionRequest` → `.permissionRequest` with no change. Confirm by reading the method; no edit needed if it splits on `/` and reads the last component.

- [ ] **Step 4: Build**

Run: `swift build`
Expected: 0 warnings, builds. (`onDecision` defaults to nil so `AppCoordinator` still compiles until Task 11.)

- [ ] **Step 5: Manual curl smoke** (temporary wiring)

Temporarily, in `AppCoordinator.applicationDidFinishLaunching`, pass an `onDecision` that echoes allow after 1s (remove after this step):
```swift
onDecision: { _, complete in DispatchQueue.main.asyncAfter(deadline: .now() + 1) { complete(.allow(scope: .once)) } }
```
Then:
```bash
swift run ClaudeNotchApp &   # note the port from ~/Library/Application Support/ClaudeNotch/bridge.json
PORT=$(python3 -c "import json;print(json.load(open('$HOME/Library/Application Support/ClaudeNotch/bridge.json'))['port'])")
TOK=$(python3 -c "import json;print(json.load(open('$HOME/Library/Application Support/ClaudeNotch/bridge.json'))['token'])")
curl -s -X POST "http://127.0.0.1:$PORT/decide/PermissionRequest" \
  -H "X-ClaudeNotch-Token: $TOK" \
  -d '{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"echo hi"}}'
```
Expected: after ~1s, prints `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}`. Then remove the temporary `onDecision` echo. Stop the app.

- [ ] **Step 6: Commit**

```bash
git add Sources/ClaudeNotchApp/Transport/HookServer.swift
git commit -m "feat: add held-open /decide endpoint to HookServer" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: notch-bridge — `decide` mode

**Files:**
- Modify: `Sources/notch-bridge/main.swift`

**Interfaces:**
- Consumes: `BridgeConfigWriter.read`, `Paths.bridgeConfigURL`.
- Produces: helper invocation `notch-bridge decide <Event>` (blocks on response, prints body, passthrough on any failure).

*No unit test (helper target) — verified end-to-end in Task 12.*

- [ ] **Step 1: Branch on `decide` mode** (edit `run()`)

Replace the argv handling + URL/timeout/response section so `decide` mode posts to `/decide/`, uses a long timeout, and prints the response body:

```swift
    let args = CommandLine.arguments
    guard args.count >= 2 else { exit(0) }

    let isDecide = args[1] == "decide"
    let eventName = isDecide ? (args.count >= 3 ? args[2] : "") : args[1]
    let subtype: String? = isDecide ? nil : (args.count >= 3 ? args[2] : nil)
    guard !eventName.isEmpty else { exit(0) }
```

Keep the stdin + env + payload assembly exactly as v1 (including `payload["hook_event_name"] = eventName` and, for non-decide, `payload["matcher"] = subtype`).

- [ ] **Step 2: Route + timeout + print body**

Replace the URL/request/semaphore block:

```swift
    guard let cfg = try? BridgeConfigWriter.read(from: Paths.bridgeConfigURL) else { exit(0) } // app down → passthrough

    let encoded = eventName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? eventName
    let route = isDecide ? "decide" : "hook"
    guard let url = URL(string: "http://127.0.0.1:\(cfg.port)/\(route)/\(encoded)"),
          let body = try? JSONSerialization.data(withJSONObject: payload) else { exit(0) }

    // Fire-and-forget monitoring: short timeout, discard body. Decide: long timeout, print body.
    let reqTimeout: TimeInterval = isDecide ? 610 : 2.0
    let waitTimeout: DispatchTime = .now() + (isDecide ? 615 : 2.5)

    var req = URLRequest(url: url, timeoutInterval: reqTimeout)
    req.httpMethod = "POST"
    req.httpBody = body
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue(cfg.token, forHTTPHeaderField: "X-ClaudeNotch-Token")

    let sem = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: req) { data, resp, _ in
        if isDecide, let data, !data.isEmpty,
           (resp as? HTTPURLResponse)?.statusCode == 200 {
            FileHandle.standardOutput.write(data)   // non-empty JSON → the decision; empty → passthrough
        }
        sem.signal()
    }.resume()
    _ = sem.wait(timeout: waitTimeout)
    exit(0)   // any failure/timeout → nothing printed → passthrough
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: 0 warnings.

- [ ] **Step 4: Manual smoke against the temporary echo** (optional, if the Task 8 echo is still present)

```bash
echo '{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"echo hi"}}' | .build/debug/notch-bridge decide PermissionRequest
```
Expected (with the app running): prints the allow JSON; with the app stopped: prints nothing and exits 0.

- [ ] **Step 5: Commit**

```bash
git add Sources/notch-bridge/main.swift
git commit -m "feat: add blocking decide mode to notch-bridge" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Decision cards in the notch

**Files:**
- Modify: `Sources/ClaudeNotchApp/UI/NotchViews.swift`
- Modify: `Sources/ClaudeNotchApp/UI/NotchController.swift`

**Interfaces:**
- Produces: `NotchViewModel.pendingDecisions: [DecisionRequest]`, `NotchViewModel.onDecide: ((DecisionRequest, Decision) -> Void)?`, `NotchController.update(pending:)`, `NotchController.onDecide`.
- Consumes: `DecisionRequest`, `Decision`, `ToolPreview`, `DiffLine`.

*No unit test (UI/app target) — verified in Task 12.*

- [ ] **Step 1: Add decision state to the view model** (edit `NotchViews.swift`)

```swift
@MainActor
final class NotchViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var pendingDecisions: [DecisionRequest] = []
    var onJump: ((Session) -> Void)?
    var onDecide: ((DecisionRequest, Decision) -> Void)?
}
```

- [ ] **Step 2: Add the card views** (append to `NotchViews.swift`)

```swift
struct DecisionCardView: View {
    let request: DecisionRequest
    let remaining: Int
    var onDecide: ((DecisionRequest, Decision) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch request.kind {
            case let .toolPermission(tool, preview):
                Text("Permission · \(tool)").font(.headline).foregroundStyle(.orange)
                previewBody(preview)
                HStack {
                    Button("Deny") { onDecide?(request, .deny(reason: "Denied from notch")) }
                    Button("Allow") { onDecide?(request, .allow(scope: .once)) }
                    Button("Allow for session") { onDecide?(request, .allow(scope: .session)) }
                }
            case let .planApproval(text):
                Text("Plan ready").font(.headline).foregroundStyle(.purple)
                ScrollView { Text(text).font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 150)
                HStack {
                    Button("Request changes") { onDecide?(request, .deny(reason: "Requested changes from notch")) }
                    Button("Approve plan") { onDecide?(request, .allow(scope: .once)) }
                }
            }
            HStack {
                Button("Answer in terminal") { onDecide?(request, .passthrough) }.font(.caption)
                Spacer()
                if remaining > 0 { Text("\(remaining) more waiting").font(.caption).foregroundStyle(.secondary) }
            }
        }
        .buttonStyle(.plain).padding(12).frame(width: 360)
    }

    @ViewBuilder private func previewBody(_ preview: ToolPreview) -> some View {
        switch preview {
        case let .diff(file, lines):
            VStack(alignment: .leading, spacing: 1) {
                Text(file).font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text((line.kind == .added ? "+ " : line.kind == .removed ? "- " : "  ") + line.text)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(line.kind == .added ? .green : line.kind == .removed ? .red : .primary)
                }
            }.frame(maxHeight: 150)
        case let .command(cmd):
            Text(cmd).font(.system(.caption, design: .monospaced))
        case let .raw(s):
            Text(s).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
        }
    }
}
```

- [ ] **Step 3: Show the card in the expanded view** (edit `NotchExpandedView.body`)

At the top of the expanded `body`, prefer the newest pending decision over the session list:

```swift
        if let req = vm.pendingDecisions.max(by: { $0.receivedAt < $1.receivedAt }) {
            DecisionCardView(request: req, remaining: vm.pendingDecisions.count - 1, onDecide: vm.onDecide)
        } else {
            // …existing session-list ForEach unchanged…
        }
```

- [ ] **Step 4: Add controller plumbing** (edit `NotchController.swift`)

```swift
    public var onDecide: ((DecisionRequest, Decision) -> Void)? { didSet { vm.onDecide = onDecide } }

    public func update(pending: [DecisionRequest]) {
        vm.pendingDecisions = pending
        desiredVisible = !pending.isEmpty || !vm.sessions.isEmpty
        if !pending.isEmpty { Task { await notch?.expand() } }   // auto-surface
        pump()   // reuse the existing coalescing pump used by update(_:)
    }
```
If the existing show/hide logic is inline in `update(_:)` rather than a `pump()` method, extract it into a private `pump()` and call it from both `update(_:)` and `update(pending:)`.

- [ ] **Step 5: Build**

Run: `swift build`
Expected: 0 warnings.

- [ ] **Step 6: Commit**

```bash
git add Sources/ClaudeNotchApp/UI
git commit -m "feat: render permission and plan decision cards in the notch" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: AppCoordinator — wire the decision path

**Files:**
- Modify: `Sources/ClaudeNotchApp/AppCoordinator.swift`

**Interfaces:**
- Consumes: `DecisionBroker`, `RememberedDecisions`, `DecisionRequest.from`, `HookServer(onDecision:)`, `NotchController.update(pending:)`/`.onDecide`, `ClaudeVersion.meetsMinimum`, `HookInstaller(decisionsEnabled:)`.

*No unit test — verified in Task 12.*

- [ ] **Step 1: Add dependencies** (edit stored props)

```swift
    private let broker = DecisionBroker(timeout: 300)
    private let remembered = RememberedDecisions()
    private var decisionsEnabled = false
```

- [ ] **Step 2: Feature-detect Claude Code** (add helper + call in `applicationDidFinishLaunching` before install)

```swift
    private func detectDecisionsSupported() -> Bool {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["claude", "--version"]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        do { try p.run(); p.waitUntilExit() } catch { return false }
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ClaudeVersion.meetsMinimum(out, (2, 1, 200))
    }
```
Set `decisionsEnabled = detectDecisionsSupported()` and pass it to the installer:
```swift
        try? HookInstaller(helperPath: helper, decisionsEnabled: decisionsEnabled).install(into: Paths.claudeSettingsURL)
```

- [ ] **Step 3: Wire `onDecision` into the server** (edit the `HookServer(...)` construction)

```swift
        server = HookServer(
            token: token,
            onEvent: { [weak self] event in Task { @MainActor in self?.handle(event) } },
            onDecision: { [weak self] event, complete in
                Task { await self?.resolveDecision(event, complete) }
            })
```

- [ ] **Step 4: Add the decision resolver + broker→UI bridge**

```swift
    private func resolveDecision(_ event: HookEvent, _ complete: @escaping (Decision) -> Void) async {
        guard let request = DecisionRequest.from(event, id: UUID().uuidString) else {
            return complete(.passthrough)
        }
        if case let .toolPermission(tool, _) = request.kind,
           remembered.isAllowed(sessionKey: request.sessionKey, tool: tool) {
            return complete(.allow(scope: .session))
        }
        let decision = await broker.decide(request)          // suspends until UI resolves or timeout
        if case .allow(scope: .session) = decision,
           case let .toolPermission(tool, _) = request.kind {
            remembered.remember(sessionKey: request.sessionKey, tool: tool)
        }
        complete(decision)
    }
```

In `applicationDidFinishLaunching`, after building `notch`:
```swift
        notch.onDecide = { [weak self] req, decision in
            Task { await self?.broker.resolve(id: req.id, decision) }
        }
        Task {
            await broker.setOnPendingChanged { pending in
                Task { @MainActor in self.notch.update(pending: pending) }
            }
        }
```

- [ ] **Step 5: Clear remembered approvals on SessionEnd** (edit `handle(_:)`)

After `store.apply(event)`, when the event ends a session, clear its remembered approvals:
```swift
        if event.name == .sessionEnd {
            remembered.clear(sessionKey: SessionKey.derive(env: event.env, sessionID: event.sessionID))
        }
```

- [ ] **Step 6: Add a menu item to clear approvals** (edit `setupMenuBar`)

Add before the separator: `menu.addItem(NSMenuItem(title: "Clear remembered approvals", action: #selector(clearApprovals), keyEquivalent: ""))` and:
```swift
    @objc private func clearApprovals() { remembered.clearAll() }
```

- [ ] **Step 7: Build**

Run: `swift build`
Expected: 0 warnings.

- [ ] **Step 8: Commit**

```bash
git add Sources/ClaudeNotchApp/AppCoordinator.swift
git commit -m "feat: wire DecisionBroker, RememberedDecisions, and version-gated install" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: Empirical passthrough check + end-to-end hardening

**Files:** none (verification + targeted fixes only).

- [ ] **Step 1: Full build + test gate**

Run: `swift build 2>&1 | tail -5` then `swift test 2>&1 | grep -E "Executed|error:"`
Expected: 0 warnings; all Core tests pass (existing 21 + the new ones).

- [ ] **Step 2: Verify the passthrough contract (the spec's one empirical unknown)**

With Claude Code ≥ 2.1.200 and the app running (`swift run ClaudeNotchApp`), start a real `claude` session in iTerm2 and trigger a tool that needs permission. In the notch, click **Answer in terminal**.
Expected: the notch returns an empty body → helper prints nothing → **Claude Code shows its normal permission prompt in the terminal**.
- If confirmed: passthrough works; done.
- If the normal prompt does NOT appear (Claude treats "no decision" as an error/deny), change the timeout/`Answer in terminal` fallback to fail-closed `deny`: in `resolveDecision`, replace the timeout/`.passthrough` outcome with `.deny(reason: "No decision (deferred)")`, and document it. Commit that change with message `fix: fail-closed deny when passthrough unsupported`.

- [ ] **Step 3: End-to-end act-in-place — permission**

Trigger an Edit/Bash permission in a real session. Expected: notch auto-expands the permission card with the diff/command; **Allow** proceeds without a terminal prompt; **Deny** blocks with the message; **Allow for session** proceeds and a second same-tool request in that session auto-allows (no card).

- [ ] **Step 4: End-to-end act-in-place — plan**

In a plan-mode session, let Claude call `ExitPlanMode`. Expected: notch shows the plan card; **Approve plan** proceeds; **Request changes** returns Claude to planning.

- [ ] **Step 5: Fail-safe checks**

(a) Quit the app, then trigger a permission → normal terminal prompt appears (helper passthrough). (b) With the app running, ignore a card > 5 min → it resolves to passthrough (terminal prompt). (c) Two sessions blocking at once → card shows "1 more waiting"; resolving advances.

- [ ] **Step 6: Uninstall integrity**

`◗` menu → Uninstall hooks. Confirm `~/.claude/settings.json` no longer contains any `notch-bridge` entries (including the `PermissionRequest` ones) and pre-existing user hooks remain.

- [ ] **Step 7: Final commit (if Step 2 required a change)**

```bash
git add -A && git commit -m "test: verify act-in-place end-to-end; harden passthrough fallback" \
  -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- §2 permission act-in-place → Tasks 2–4, 8–11. ✓
- §2 plan act-in-place (`ExitPlanMode`) → Tasks 3, 7, 10, 11. ✓
- §2 "ask stays v1" → untouched (no `AskUserQuestion` work). ✓
- §5 blocking round-trip → Tasks 8 (server hold-open), 9 (helper block+print). ✓
- §6 components → all mapped to tasks (Decision/Encoder/Renderer/Remembered/Broker/HookEvent/Installer/Server/Helper/UI/Coordinator). ✓
- §7 data model & transitions → Tasks 1, 3; existing `.permissionRequest → needsPermission` reused. ✓
- §8 wire protocol (`/decide`, stdout JSON, hook config with sync + timeout) → Tasks 4, 7, 8, 9. ✓
- §9 cards / click-only / auto-surface → Task 10. ✓
- §10 multiple pending → Tasks 6 (snapshot), 10 ("N more waiting"). ✓
- §11 allow-for-session (in-memory, clear) → Tasks 5, 11. ✓
- §12 fail-safe / passthrough / timeout margin (app 300s < hook 600s) → Tasks 6, 8, 9, 11, 12. ✓
- §14 security (token on `/decide`, in-memory approvals) → Tasks 8, 5/11. ✓
- §15 feature detection (≥ 2.1.200) → Task 7 (parser) + Task 11 (exec). ✓
- §17 testing (Encoder/Renderer/Remembered/Broker/SessionStore-transitions) → Tasks 2–7. ✓

**Placeholder scan:** No TBD/TODO; every code step shows complete code; every command shows expected output. ✓

**Type consistency:** `Decision`/`AllowScope`/`DecisionKind`/`DecisionRequest` defined in Task 3 and used identically in Tasks 4, 6, 8, 10, 11. `ToolPreview`/`DiffLine` from Task 2 used in Tasks 3, 10. `SessionKey.derive` from Task 1 used in Tasks 3, 11. `DecisionEncoder.stdoutJSON(for:)` from Task 4 used in Task 8. `DecisionBroker.decide/resolve/setOnPendingChanged/snapshotPending` from Task 6 used in Task 11. `HookInstaller(helperPath:decisionsEnabled:)` from Task 7 used in Task 11. Consistent. ✓
