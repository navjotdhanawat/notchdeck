# Multi-Agent Support (AgentProvider seam + Codex) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the eleven Claude-hardwired edges behind a pluggable `AgentProvider` seam and ship full Codex CLI support (monitoring + jump + act-in-place + usage/cost) as the first adapter proving the seam.

**Architecture:** A per-concern provider seam (pure, `ClaudeNotchCore`) mirroring the shipped terminal seam. Each agent is an `AgentProvider` vending small pieces (`installProfile`, `eventMapper`, `decisionMapper`, `decisionEncoder`, `transcriptParser`, `costEstimator`, `toolRenderer`); a `BaseAgentProvider`-style protocol extension supplies shared defaults (the byte-identical decode + decision encoder) so Codex reuses them verbatim. An `agentID` travels on the wire (installer bakes `--agent <id>` into the bridge argv; the bridge injects `agent_id`; `HookEvent.agentID` carries it); an `AgentRegistry` resolves the provider per event, falling back to Claude for a missing/unknown id.

**Tech Stack:** Swift 6 tools (`swift-tools-version: 6.0`, language mode v5), macOS 14+, SwiftPM, XCTest. Core is a pure library (no AppKit). Build: `swift build`. Test: `swift test`.

**Design spec:** `docs/superpowers/specs/2026-07-23-multi-agent-support-design.md`.

## Global Constraints

- **Repo policy:** Local git only — no remote, never push. **No JIRA** for this project — commit messages use a Conventional-Commits type with **no ticket prefix**. End every commit body with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`. Work happens on branch `feat/claudenotch-multi-agent` (already created).
- **Claude behavior is byte-for-byte unchanged.** Same hooks installed into `~/.claude/settings.json`, same decode, same decision JSON, same usage/cost. Every Phase-A task is a behavior-preserving refactor; `swift test` must stay green throughout.
- **Back-compat:** a missing/unknown `agent_id` (old installs, unknown future agent) resolves to the **Claude** provider. The bridge accepts argv both with and without `--agent <id>`.
- **Layer discipline:** all seams are pure and live in `ClaudeNotchCore`. Only `HookInstaller` file-I/O, `AgentProvider.isPresent()` detection, and the version subprocess touch the OS; they are invoked from `AppCoordinator` (App). Core must not import AppKit.
- **`TokenUsage` stays a four-bucket superset** (`input`/`output`/`cacheCreation`/`cacheRead`). OpenAI has no cache-write bucket → Codex maps cached-input → `cacheRead`, `cacheCreation = 0`.
- **Three verification items** (confirm during the noted steps; code is written tolerant so a wrong guess degrades to "monitor works, cost nil" rather than crashing):
  1. Codex rollout/transcript token-usage line schema — **Task 12, Step 1** (inspect a real rollout).
  2. Codex min hook version — **not gated**: Codex installs all hooks whenever present; an old Codex without hook support simply ignores `hooks.json` (Task 13).
  3. OpenAI/Codex model price values — **Task 12** (`OpenAIPricing` table; verify against current pricing).
- **KEEP THE BUILD GREEN EVERY TASK (execution correction, 2026-07-23):** `swift test` compiles the whole package including the `ClaudeNotchApp` and `notch-bridge` targets. Therefore a Core signature change that breaks `AppCoordinator` breaks `swift test` too — the earlier "run Core tests via `--filter` until Task 11" notes are **superseded**. Every task must leave `swift build && swift test` fully green: any task that renames/removes a symbol used by `Sources/ClaudeNotchApp/` MUST update those call sites in the same commit. Net effect on sequencing (scope/architecture unchanged): Task 4 also edits `AppCoordinator.resolveDecision`; Task 5 also edits the `UsageTracker` construction + `update(...)` call; Task 6 also edits the `CLIVersion` call site; **Task 7 slims to additive types only** (`HookSpec`/`VersionGate`/`AgentInstallProfile`); **Task 8 absorbs the `HookInstaller` refactor + `HookInstallerTests` rewrite + the App install switch**; Task 10 passes a provider into `store.apply`; **Task 11 slims** to `HookServer` registry injection + final provider-routed decisions/usage + the `presentProviders()` install loop + interim-shim cleanup. Verify each task with full `swift build && swift test`.

---

## Phase A — Pluggable seam, Claude extracted (no behavior change)

### Task 1: Add `agentID` routing field to `HookEvent`

**Files:**
- Modify: `Sources/ClaudeNotchCore/Model/HookEvent.swift`
- Test: `Tests/ClaudeNotchCoreTests/HookEventTests.swift`

**Interfaces:**
- Produces: `HookEvent.agentID: String` (stored, defaults to `"claude"`); `HookEvent.init(..., agentID: String = "claude", ...)`; `static HookEvent.peekAgentID(_ data: Data) -> String`. `HookEvent.decode` reads `obj["agent_id"] as? String` (default `"claude"`).

- [ ] **Step 1: Write the failing tests** — append to `HookEventTests.swift`:

```swift
    func testAgentIDDefaultsToClaudeWhenAbsent() throws {
        let e = try decode(#"{"session_id":"s1","cwd":"/w"}"#, .stop)
        XCTAssertEqual(e.agentID, "claude")
    }

    func testAgentIDDecodedFromPayload() throws {
        let e = try decode(#"{"session_id":"s1","cwd":"/w","agent_id":"codex"}"#, .stop)
        XCTAssertEqual(e.agentID, "codex")
    }

    func testPeekAgentIDReadsRawWithoutFullDecode() {
        XCTAssertEqual(HookEvent.peekAgentID(Data(#"{"agent_id":"codex","session_id":"s1"}"#.utf8)), "codex")
        XCTAssertEqual(HookEvent.peekAgentID(Data(#"{"session_id":"s1"}"#.utf8)), "claude")
        XCTAssertEqual(HookEvent.peekAgentID(Data("not json".utf8)), "claude")
    }
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter HookEventTests`
Expected: FAIL — `value of type 'HookEvent' has no member 'agentID'` / `no member 'peekAgentID'`.

- [ ] **Step 3: Implement** — in `HookEvent.swift`, add the stored field, init param, decode line, and peek helper.

Add the property (after `public let name: HookEventName`):

```swift
    public let agentID: String
```

Change the initializer signature and body — replace the existing `init(...)` with:

```swift
    public init(name: HookEventName, agentID: String = "claude", sessionID: String, cwd: String, matcher: String?,
                toolName: String?, transcriptPath: String?, env: HookEnv, toolInput: Data? = nil, receivedAt: Date) {
        self.name = name; self.agentID = agentID; self.sessionID = sessionID; self.cwd = cwd; self.matcher = matcher
        self.toolName = toolName; self.transcriptPath = transcriptPath; self.env = env
        self.toolInput = toolInput; self.receivedAt = receivedAt
    }
```

In `decode(...)`, pass `agentID` (add just before `return HookEvent(`):

```swift
        let agentID = (obj["agent_id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "claude"
```

and add `agentID: agentID,` as the second argument of the returned `HookEvent(`:

```swift
        return HookEvent(
            name: name,
            agentID: agentID,
            sessionID: sessionID,
```

Add the peek helper (after `decode`):

```swift
    /// Cheaply read `agent_id` from a raw hook payload without a full decode, so the
    /// transport can pick the right provider before decoding. Defaults to "claude".
    public static func peekAgentID(_ data: Data) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = obj["agent_id"] as? String, !id.isEmpty else { return "claude" }
        return id
    }
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter HookEventTests`
Expected: PASS (all HookEventTests, including the three new ones).

- [ ] **Step 5: Full suite still green**

Run: `swift build && swift test`
Expected: PASS — the defaulted `agentID` param keeps every existing `HookEvent(...)` call compiling.

- [ ] **Step 6: Commit**

```bash
git add Sources/ClaudeNotchCore/Model/HookEvent.swift Tests/ClaudeNotchCoreTests/HookEventTests.swift
git commit -m "feat: add agentID routing field to HookEvent

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Seam protocols + shared default implementations

**Files:**
- Create: `Sources/ClaudeNotchCore/Agent/AgentSeams.swift`
- Test: `Tests/ClaudeNotchCoreTests/AgentSeamsTests.swift`

**Interfaces:**
- Produces:
  - `protocol HookEventMapping: Sendable { func decode(_ data: Data, name: HookEventName, now: Date) throws -> HookEvent }`
  - `protocol DecisionMapping: Sendable { func request(from event: HookEvent, id: String, sessionKey: String) -> DecisionRequest? }`
  - `protocol DecisionEncoding: Sendable { func stdoutJSON(for decision: Decision) -> Data?; func answerStdoutJSON(_ answers: [String: String], originalToolInput: Data?) -> Data? }`
  - `protocol TranscriptParsing: Sendable { func parse(_ chunk: String) -> (model: String?, usage: TokenUsage) }`
  - `protocol ToolRendering: Sendable { func render(tool: String, input: [String: Any]) -> ToolPreview; func actionLabel(toolName: String?, input: [String: Any]?) -> String? }`
  - `struct DefaultHookEventMapper: HookEventMapping` (delegates to `HookEvent.decode`)
  - `struct HookSpecificOutputEncoder: DecisionEncoding` (delegates to `DecisionEncoder`)

- [ ] **Step 1: Write the failing tests** — create `Tests/ClaudeNotchCoreTests/AgentSeamsTests.swift`:

```swift
import XCTest
@testable import ClaudeNotchCore

final class AgentSeamsTests: XCTestCase {
    func testDefaultMapperDecodesAgentAndCoreFields() throws {
        let json = #"{"session_id":"s1","cwd":"/w","tool_name":"Bash","agent_id":"codex"}"#
        let e = try DefaultHookEventMapper().decode(Data(json.utf8), name: .preToolUse, now: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(e.agentID, "codex")
        XCTAssertEqual(e.toolName, "Bash")
    }

    // Compare parsed JSON (order-independent). DecisionEncoder does NOT use .sortedKeys, so a raw
    // Data byte-compare of two independent serializations is nondeterministic — assert semantics.
    private func json(_ d: Data?) -> NSDictionary? {
        guard let d else { return nil }
        return (try? JSONSerialization.jsonObject(with: d)) as? NSDictionary
    }

    func testSharedEncoderMatchesDecisionEncoder() {
        let enc = HookSpecificOutputEncoder()
        XCTAssertEqual(json(enc.stdoutJSON(for: .allow(scope: .once))),
                       json(DecisionEncoder.stdoutJSON(for: .allow(scope: .once))))
        XCTAssertEqual(json(enc.stdoutJSON(for: .deny(reason: "no"))),
                       json(DecisionEncoder.stdoutJSON(for: .deny(reason: "no"))))
        XCTAssertNil(enc.stdoutJSON(for: .passthrough))
        let answers = ["Q": "A"]
        let ti = Data(#"{"questions":[]}"#.utf8)
        XCTAssertEqual(json(enc.answerStdoutJSON(answers, originalToolInput: ti)),
                       json(DecisionEncoder.answerStdoutJSON(answers, originalToolInput: ti)))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter AgentSeamsTests`
Expected: FAIL — `cannot find 'DefaultHookEventMapper'` / `'HookSpecificOutputEncoder'`.

- [ ] **Step 3: Implement** — create `Sources/ClaudeNotchCore/Agent/AgentSeams.swift`:

```swift
import Foundation

// MARK: - Per-concern agent seams (pure). One AgentProvider (see AgentProvider.swift) vends these.

/// Turns a raw hook payload into a `HookEvent`. Default = the shared Claude/Codex field layout.
public protocol HookEventMapping: Sendable {
    func decode(_ data: Data, name: HookEventName, now: Date) throws -> HookEvent
}

/// Turns a decoded decision-bearing event into a `DecisionRequest`, or nil to pass through.
public protocol DecisionMapping: Sendable {
    func request(from event: HookEvent, id: String, sessionKey: String) -> DecisionRequest?
}

/// Encodes a `Decision` into the agent's hook-stdout contract. Default = the shared
/// `hookSpecificOutput` envelope (identical for Claude and Codex).
public protocol DecisionEncoding: Sendable {
    func stdoutJSON(for decision: Decision) -> Data?
    func answerStdoutJSON(_ answers: [String: String], originalToolInput: Data?) -> Data?
}

/// Parses a transcript JSONL chunk into (latest model, summed token usage).
public protocol TranscriptParsing: Sendable {
    func parse(_ chunk: String) -> (model: String?, usage: TokenUsage)
}

/// Renders a tool call for the permission card and the glance-row action label.
public protocol ToolRendering: Sendable {
    func render(tool: String, input: [String: Any]) -> ToolPreview
    func actionLabel(toolName: String?, input: [String: Any]?) -> String?
}

// MARK: - Shared defaults (used verbatim by both Claude and Codex)

/// Default inbound decode: Claude and Codex share the same hook field names
/// (`session_id`/`cwd`/`tool_name`/`tool_input`/`transcript_path` + injected `agent_id`).
public struct DefaultHookEventMapper: HookEventMapping {
    public init() {}
    public func decode(_ data: Data, name: HookEventName, now: Date) throws -> HookEvent {
        try HookEvent.decode(data, name: name, now: now)
    }
}

/// Default decision encoder: the `hookSpecificOutput` envelope Claude and Codex both accept.
public struct HookSpecificOutputEncoder: DecisionEncoding {
    public init() {}
    public func stdoutJSON(for decision: Decision) -> Data? {
        DecisionEncoder.stdoutJSON(for: decision)
    }
    public func answerStdoutJSON(_ answers: [String: String], originalToolInput: Data?) -> Data? {
        DecisionEncoder.answerStdoutJSON(answers, originalToolInput: originalToolInput)
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter AgentSeamsTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchCore/Agent/AgentSeams.swift Tests/ClaudeNotchCoreTests/AgentSeamsTests.swift
git commit -m "feat: add per-concern agent seam protocols and shared defaults

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `ClaudeToolRenderer` (ToolRendering)

**Files:**
- Modify: `Sources/ClaudeNotchCore/Domain/ToolInputRenderer.swift`
- Test: `Tests/ClaudeNotchCoreTests/ToolInputRendererTests.swift` (unchanged; add one case)

**Interfaces:**
- Consumes: `ToolRendering` (Task 2), `ToolPreview`.
- Produces: `struct ClaudeToolRenderer: ToolRendering` — delegates to the existing `ToolInputRenderer` enum (kept as the implementation).

- [ ] **Step 1: Write the failing test** — append to `ToolInputRendererTests.swift`:

```swift
    func testClaudeToolRendererMatchesEnum() {
        let r = ClaudeToolRenderer()
        XCTAssertEqual(r.render(tool: "Bash", input: ["command": "ls"]), .command("ls"))
        XCTAssertEqual(r.actionLabel(toolName: "Read", input: ["file_path": "/a/b.swift"]), "Read b.swift")
        XCTAssertNil(r.actionLabel(toolName: nil, input: nil))
    }
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter ToolInputRendererTests`
Expected: FAIL — `cannot find 'ClaudeToolRenderer'`.

- [ ] **Step 3: Implement** — at the bottom of `ToolInputRenderer.swift`, add:

```swift
/// Claude Code's tool catalog as a `ToolRendering` seam. Delegates to `ToolInputRenderer`,
/// which stays the pure implementation of Claude's tool-name/input-key conventions.
public struct ClaudeToolRenderer: ToolRendering {
    public init() {}
    public func render(tool: String, input: [String: Any]) -> ToolPreview {
        ToolInputRenderer.render(tool: tool, input: input)
    }
    public func actionLabel(toolName: String?, input: [String: Any]?) -> String? {
        ToolInputRenderer.actionLabel(toolName: toolName, input: input)
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter ToolInputRendererTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchCore/Domain/ToolInputRenderer.swift Tests/ClaudeNotchCoreTests/ToolInputRendererTests.swift
git commit -m "feat: add ClaudeToolRenderer conforming to ToolRendering seam

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `ClaudeDecisionMapper` (DecisionMapping) — replace `DecisionRequest.from`

**Files:**
- Modify: `Sources/ClaudeNotchCore/Model/Decision.swift`
- Test: `Tests/ClaudeNotchCoreTests/DecisionTests.swift`

**Interfaces:**
- Consumes: `DecisionMapping`, `ToolRendering` (Tasks 2–3).
- Produces: `struct ClaudeDecisionMapper: DecisionMapping` with `init(renderer: ToolRendering = ClaudeToolRenderer())` and `request(from:id:sessionKey:) -> DecisionRequest?`. The old `DecisionRequest.from(_:id:identifiers:)` extension is **removed**; its question-parsing helper moves into the mapper.

- [ ] **Step 1: Rewrite the failing tests** — replace the body of `DecisionTests.swift` with (the mapper takes an explicit `sessionKey`, so the test passes one directly):

```swift
import XCTest
@testable import ClaudeNotchCore

final class DecisionTests: XCTestCase {
    private let mapper = ClaudeDecisionMapper()

    private func event(tool: String, input: [String: Any]) -> HookEvent {
        let data = try! JSONSerialization.data(withJSONObject: input)
        return HookEvent(name: .permissionRequest, sessionID: "s1", cwd: "/w", matcher: "*",
                         toolName: tool, transcriptPath: nil,
                         env: HookEnv(values: ["ITERM_SESSION_ID": "w0t1p0:UUID-1"]), toolInput: data,
                         receivedAt: Date(timeIntervalSince1970: 5))
    }

    func testFromEditIsToolPermission() {
        let req = mapper.request(from: event(tool: "Edit",
            input: ["file_path": "a.ts", "old_string": "x", "new_string": "y"]),
            id: "r1", sessionKey: "iterm2:UUID-1")
        XCTAssertEqual(req?.sessionKey, "iterm2:UUID-1")
        guard case let .toolPermission(tool, preview)? = req?.kind else { return XCTFail() }
        XCTAssertEqual(tool, "Edit")
        guard case .diff = preview else { return XCTFail("expected diff preview") }
    }

    func testFromExitPlanModeIsPlanApproval() {
        let req = mapper.request(from: event(tool: "ExitPlanMode", input: ["plan": "1. do X\n2. do Y"]),
                                 id: "r2", sessionKey: "k")
        guard case let .planApproval(text)? = req?.kind else { return XCTFail() }
        XCTAssertEqual(text, "1. do X\n2. do Y")
    }

    func testFromAskUserQuestionIsQuestion() {
        let input: [String: Any] = ["questions": [["question": "Pick?", "header": "H", "multiSelect": false,
            "options": [["label": "A", "description": "aa"], ["label": "B", "description": nil as Any? as Any]]]]]
        let req = mapper.request(from: event(tool: "AskUserQuestion", input: input), id: "r4", sessionKey: "k")
        guard case let .question(qs)? = req?.kind else { return XCTFail() }
        XCTAssertEqual(qs.first?.question, "Pick?")
        XCTAssertEqual(qs.first?.options.first?.label, "A")
    }

    func testFromWithoutToolNameIsNil() {
        let e = HookEvent(name: .permissionRequest, sessionID: "s1", cwd: "/w", matcher: nil,
                          toolName: nil, transcriptPath: nil, env: HookEnv(), toolInput: nil,
                          receivedAt: Date(timeIntervalSince1970: 5))
        XCTAssertNil(mapper.request(from: e, id: "r3", sessionKey: "k"))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter DecisionTests`
Expected: FAIL — `cannot find 'ClaudeDecisionMapper'`.

- [ ] **Step 3: Implement** — in `Decision.swift`, **delete** the entire `public extension DecisionRequest { ... }` block (the `from` + `parseQuestions`) and replace it with:

```swift
/// Claude Code's tool → DecisionRequest mapping: AskUserQuestion → question,
/// ExitPlanMode → plan approval, everything else → a tool-permission card.
public struct ClaudeDecisionMapper: DecisionMapping {
    private let renderer: ToolRendering
    public init(renderer: ToolRendering = ClaudeToolRenderer()) { self.renderer = renderer }

    public func request(from event: HookEvent, id: String, sessionKey: String) -> DecisionRequest? {
        guard let tool = event.toolName else { return nil }
        let input = event.toolInputDict ?? [:]
        let kind: DecisionKind
        if tool == "AskUserQuestion" {
            kind = .question(questions: Self.parseQuestions(input))
        } else if tool == "ExitPlanMode" {
            kind = .planApproval(text: (input["plan"] as? String) ?? "")
        } else {
            kind = .toolPermission(tool: tool, preview: renderer.render(tool: tool, input: input))
        }
        return DecisionRequest(id: id, sessionKey: sessionKey, kind: kind, receivedAt: event.receivedAt)
    }

    private static func parseQuestions(_ input: [String: Any]) -> [QuestionSpec] {
        let raw = (input["questions"] as? [[String: Any]]) ?? []
        return raw.map { q in
            let opts = ((q["options"] as? [[String: Any]]) ?? []).map {
                QuestionOption(label: ($0["label"] as? String) ?? "", description: $0["description"] as? String)
            }
            return QuestionSpec(
                question: (q["question"] as? String) ?? "",
                header: q["header"] as? String,
                options: opts,
                multiSelect: (q["multiSelect"] as? Bool) ?? false
            )
        }
    }
}
```

> Note: `AppCoordinator` still references `DecisionRequest.from` at this point — it is updated in **Task 11**. The Core library and its tests compile now; the App target is rewired later in Phase A. Run Core tests via `--filter` until Task 11.

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter DecisionTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchCore/Model/Decision.swift Tests/ClaudeNotchCoreTests/DecisionTests.swift
git commit -m "refactor: replace DecisionRequest.from with ClaudeDecisionMapper seam

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Transcript parser seam + reader/usage parameterization + `ClaudePricing`

**Files:**
- Modify: `Sources/ClaudeNotchCore/Domain/TranscriptParser.swift`
- Modify: `Sources/ClaudeNotchCore/Domain/TranscriptReader.swift`
- Modify: `Sources/ClaudeNotchCore/Domain/UsageTracker.swift`
- Modify: `Sources/ClaudeNotchCore/Domain/CostEstimator.swift`
- Test: `Tests/ClaudeNotchCoreTests/TranscriptParserTests.swift` (new)

**Interfaces:**
- Consumes: `TranscriptParsing` (Task 2), `CostEstimator`, `TokenUsage`, `TranscriptScan`.
- Produces:
  - `struct ClaudeTranscriptParser: TranscriptParsing` (delegates to the kept `TranscriptParser` enum).
  - `TranscriptReading.scan(path:from:parser:) -> TranscriptScan` (parser now injected per call).
  - `UsageTracker.init(reader:)` (no estimator) and `UsageTracker.update(transcriptPath:parser:estimator:) -> SessionUsage`.
  - `struct ClaudePricing: CostEstimator` (renamed from `BundledPricing`).

- [ ] **Step 1: Write the failing test** — create `Tests/ClaudeNotchCoreTests/TranscriptParserTests.swift`:

```swift
import XCTest
@testable import ClaudeNotchCore

final class TranscriptParserTests: XCTestCase {
    func testClaudeParserSumsUsageAndReadsModel() {
        let chunk = """
        {"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"input_tokens":10,"output_tokens":5,"cache_creation_input_tokens":2,"cache_read_input_tokens":1}}}
        {"type":"user","message":{"role":"user"}}
        {"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"input_tokens":3,"output_tokens":4}}}
        """
        let (model, usage) = ClaudeTranscriptParser().parse(chunk)
        XCTAssertEqual(model, "claude-opus-4-8")
        XCTAssertEqual(usage, TokenUsage(input: 13, output: 9, cacheCreation: 2, cacheRead: 1))
    }

    func testClaudePricingReturnsNilForUnknownModel() {
        XCTAssertNil(ClaudePricing().cost(model: "gpt-nope", tokens: TokenUsage(input: 1)))
        XCTAssertNotNil(ClaudePricing().cost(model: "claude-opus-4-8", tokens: TokenUsage(input: 1_000_000)))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter TranscriptParserTests`
Expected: FAIL — `cannot find 'ClaudeTranscriptParser'` / `'ClaudePricing'`.

- [ ] **Step 3a: Implement the Claude parser** — at the bottom of `TranscriptParser.swift`, add:

```swift
/// Claude Code's transcript schema as a `TranscriptParsing` seam. Delegates to the pure
/// `TranscriptParser` enum, which stays the implementation of Claude's `message.usage` layout.
public struct ClaudeTranscriptParser: TranscriptParsing {
    public init() {}
    public func parse(_ chunk: String) -> (model: String?, usage: TokenUsage) {
        TranscriptParser.parse(chunk)
    }
}
```

- [ ] **Step 3b: Parameterize the reader** — in `TranscriptReader.swift`, change the protocol and the file reader to take a parser:

Replace the protocol:

```swift
public protocol TranscriptReading: Sendable {
    func scan(path: String, from offset: Int, parser: TranscriptParsing) -> TranscriptScan
}
```

Replace the `scan` signature and its parse call in `FileTranscriptReader`:

```swift
    public func scan(path: String, from offset: Int, parser: TranscriptParsing) -> TranscriptScan {
```

and

```swift
            let (model, usage) = parser.parse(String(decoding: complete, as: UTF8.self))
```

- [ ] **Step 3c: Parameterize UsageTracker** — replace `UsageTracker.swift` init + update:

```swift
    private var entries: [String: Entry] = [:]
    private let reader: TranscriptReading

    public init(reader: TranscriptReading) {
        self.reader = reader
    }

    /// Incrementally read `transcriptPath` using the agent's parser + estimator, and return current usage.
    public func update(transcriptPath: String, parser: TranscriptParsing, estimator: CostEstimator) -> SessionUsage {
        let previous = entries[transcriptPath] ?? Entry(offset: 0, totals: TokenUsage(), model: nil)
        let scan = reader.scan(path: transcriptPath, from: previous.offset, parser: parser)
        let entry: Entry
        if scan.newOffset < previous.offset {
            entry = Entry(offset: scan.newOffset, totals: scan.usageDelta, model: scan.model)
        } else {
            entry = Entry(offset: scan.newOffset,
                          totals: previous.totals + scan.usageDelta,
                          model: scan.model ?? previous.model)
        }
        entries[transcriptPath] = entry
        let cost = estimator.cost(model: entry.model, tokens: entry.totals)
        return SessionUsage(model: entry.model, tokens: entry.totals, costUSD: cost)
    }
```

(Leave `forget(transcriptPath:)` unchanged.)

- [ ] **Step 3d: Rename pricing** — in `CostEstimator.swift`, rename `BundledPricing` to `ClaudePricing`:

```swift
/// Claude/Anthropic per-model, per-bucket pricing (USD per million tokens).
/// Prices reflect Anthropic public pricing as of 2026-07 — verify and update when prices change.
public struct ClaudePricing: CostEstimator {
```

(Keep the rest of the struct — `Price`, `table`, `cost`, `match` — identical.)

> Note: `AppCoordinator.swift:19` still says `UsageTracker(reader:..., estimator: BundledPricing())`. It is rewired in **Task 11**. Until then the App target won't compile — run Core tests with `--filter`.

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter TranscriptParserTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchCore/Domain/TranscriptParser.swift Sources/ClaudeNotchCore/Domain/TranscriptReader.swift Sources/ClaudeNotchCore/Domain/UsageTracker.swift Sources/ClaudeNotchCore/Domain/CostEstimator.swift Tests/ClaudeNotchCoreTests/TranscriptParserTests.swift
git commit -m "refactor: parameterize transcript parsing per agent; rename BundledPricing to ClaudePricing

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Generalize the version gate (`ClaudeVersion` → `CLIVersion`)

**Files:**
- Rename/Modify: `Sources/ClaudeNotchCore/Install/ClaudeVersion.swift` → `Sources/ClaudeNotchCore/Install/CLIVersion.swift`
- Rename/Modify: `Tests/ClaudeNotchCoreTests/ClaudeVersionTests.swift` → `Tests/ClaudeNotchCoreTests/CLIVersionTests.swift`

**Interfaces:**
- Produces: `enum CLIVersion { static func parse(_:) -> (Int,Int,Int)?; static func meetsMinimum(_:_:) -> Bool }`. `parse` scans for the first `\d+\.\d+\.\d+` substring anywhere in the output (so it handles both `"2.1.217 (Claude Code)"` and a `"codex-cli 0.20.0"`-style prefix).

- [ ] **Step 1: Create the renamed failing test** — create `Tests/ClaudeNotchCoreTests/CLIVersionTests.swift` and delete the old file:

```swift
import XCTest
@testable import ClaudeNotchCore

final class CLIVersionTests: XCTestCase {
    func testParsesClaudeStyle() {
        XCTAssertEqual(CLIVersion.parse("2.1.217 (Claude Code)")!.0, 2)
        XCTAssertEqual(CLIVersion.parse("2.1.217 (Claude Code)")!.2, 217)
    }
    func testParsesPrefixedStyle() {
        // A CLI that prints a name before the semver (e.g. "codex-cli 0.20.3").
        XCTAssertEqual(CLIVersion.parse("codex-cli 0.20.3")!.1, 20)
        XCTAssertEqual(CLIVersion.parse("codex-cli 0.20.3")!.2, 3)
    }
    func testMeetsMinimum() {
        XCTAssertTrue(CLIVersion.meetsMinimum("2.1.217 (Claude Code)", (2, 1, 200)))
        XCTAssertFalse(CLIVersion.meetsMinimum("2.1.199", (2, 1, 200)))
        XCTAssertTrue(CLIVersion.meetsMinimum("2.2.0", (2, 1, 200)))
        XCTAssertFalse(CLIVersion.meetsMinimum("garbage", (2, 1, 200)))
    }
}
```

```bash
git rm Tests/ClaudeNotchCoreTests/ClaudeVersionTests.swift
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter CLIVersionTests`
Expected: FAIL — `cannot find 'CLIVersion'`.

- [ ] **Step 3: Implement** — create `Sources/ClaudeNotchCore/Install/CLIVersion.swift` (and `git rm` the old file):

```swift
import Foundation

/// Parses a semantic version out of a CLI's `--version` output. Robust to a leading program
/// name (e.g. "codex-cli 0.20.3") or a trailing suffix (e.g. "2.1.217 (Claude Code)") by
/// scanning for the first `major.minor.patch` triple anywhere in the string.
public enum CLIVersion {
    public static func parse(_ output: String) -> (Int, Int, Int)? {
        let scanned = output as NSString
        let re = try? NSRegularExpression(pattern: #"(\d+)\.(\d+)\.(\d+)"#)
        guard let m = re?.firstMatch(in: output, range: NSRange(location: 0, length: scanned.length)),
              m.numberOfRanges == 4,
              let major = Int(scanned.substring(with: m.range(at: 1))),
              let minor = Int(scanned.substring(with: m.range(at: 2))),
              let patch = Int(scanned.substring(with: m.range(at: 3))) else { return nil }
        return (major, minor, patch)
    }

    public static func meetsMinimum(_ output: String, _ min: (Int, Int, Int)) -> Bool {
        guard let v = parse(output) else { return false }
        if v.0 != min.0 { return v.0 > min.0 }
        if v.1 != min.1 { return v.1 > min.1 }
        return v.2 >= min.2
    }
}
```

```bash
git rm Sources/ClaudeNotchCore/Install/ClaudeVersion.swift
```

> Note: `AppCoordinator.swift:136` still calls `ClaudeVersion.meetsMinimum` — updated in Task 11.

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter CLIVersionTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchCore/Install/CLIVersion.swift Tests/ClaudeNotchCoreTests/CLIVersionTests.swift
git commit -m "refactor: generalize ClaudeVersion into CLIVersion with tolerant semver scan

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: `HookSpec` + `AgentInstallProfile` + `HookInstaller` refactor

**Files:**
- Create: `Sources/ClaudeNotchCore/Agent/AgentInstallProfile.swift`
- Modify: `Sources/ClaudeNotchCore/Install/HookInstaller.swift`
- Test: `Tests/ClaudeNotchCoreTests/HookInstallerTests.swift`

**Interfaces:**
- Produces:
  - `struct HookSpec: Sendable { let event, matcher, args: String; let isAsync: Bool; let timeout: Int? }`
  - `struct VersionGate: Sendable { let binary: String; let minVersion: (Int, Int, Int) }`
  - `struct AgentInstallProfile: Sendable { let settingsURL: URL; let backupFilename: String; let monitorSpecs: [HookSpec]; let decisionSpecs: [HookSpec]; let versionGate: VersionGate? }`
  - `HookInstaller.init(helperPath: String, specs: [HookSpec], backupFilename: String)` and `install(into:)` / `uninstall(from:)` / `status(url:)` unchanged in behavior. Each spec's `args` is written verbatim after the quoted helper path, so the caller decides whether to embed `--agent <id>` (see Task 8's Claude profile).

- [ ] **Step 1: Update the failing tests** — replace `HookInstallerTests.swift` so it drives the installer via explicit specs (mirroring today's Claude specs; note the `--agent claude` prefix that Task 8 will bake into the profile is asserted here so downstream stays consistent):

```swift
import XCTest
@testable import ClaudeNotchCore

final class HookInstallerTests: XCTestCase {
    private func tmpURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("settings-\(UUID().uuidString).json")
    }
    private func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent()
            .appendingPathComponent("settings.json.claudenotch-backup"))
    }
    private func read(_ url: URL) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    }
    private func installer(_ helper: String, decisions: Bool) -> HookInstaller {
        let p = ClaudeAgentProvider().installProfile
        return HookInstaller(helperPath: helper,
                             specs: p.monitorSpecs + (decisions ? p.decisionSpecs : []),
                             backupFilename: p.backupFilename)
    }

    func testInstallIntoMissingFileCreatesHooks() throws {
        let url = tmpURL(); defer { remove(url) }
        let inst = installer("/App/notch-bridge", decisions: false)
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
        let url = tmpURL(); defer { remove(url) }
        let existing = #"""
        {"model":"opus","hooks":{"Stop":[{"matcher":"*","hooks":[{"type":"command","command":"/usr/bin/my-own-thing"}]}]}}
        """#
        try Data(existing.utf8).write(to: url)
        try installer("/App/notch-bridge", decisions: false).install(into: url)

        let root = try read(url)
        XCTAssertEqual(root["model"] as? String, "opus")
        let stop = (root["hooks"] as! [String: Any])["Stop"] as! [[String: Any]]
        XCTAssertEqual(stop.count, 1)
        let group = stop[0]
        XCTAssertEqual(group["matcher"] as? String, "*")
        let cmds = (group["hooks"] as! [[String: Any]]).map { $0["command"] as! String }
        XCTAssertTrue(cmds.contains("/usr/bin/my-own-thing"))
        XCTAssertTrue(cmds.contains { $0.hasPrefix("\"/App/notch-bridge\"") })
    }

    func testUninstallRemovesOnlyOurs() throws {
        let url = tmpURL(); defer { remove(url) }
        let existing = #"""
        {"hooks":{"Stop":[{"matcher":"*","hooks":[{"type":"command","command":"/usr/bin/my-own-thing"}]}]}}
        """#
        try Data(existing.utf8).write(to: url)
        let inst = installer("/App/notch-bridge", decisions: false)
        try inst.install(into: url)
        try inst.uninstall(from: url)

        XCTAssertFalse(try inst.status(url: url))
        let stop = (try read(url)["hooks"] as! [String: Any])["Stop"] as! [[String: Any]]
        let cmds = stop.flatMap { ($0["hooks"] as! [[String: Any]]).map { $0["command"] as! String } }
        XCTAssertEqual(cmds, ["/usr/bin/my-own-thing"])
    }

    func testInstallIsIdempotent() throws {
        let url = tmpURL(); defer { remove(url) }
        let inst = installer("/App/notch-bridge", decisions: false)
        try inst.install(into: url)
        try inst.install(into: url)
        let hooks = try read(url)["hooks"] as! [String: Any]
        let stop = hooks["Stop"] as! [[String: Any]]
        let ours = stop.flatMap { ($0["hooks"] as! [[String: Any]]) }
            .filter { ($0["command"] as! String).hasPrefix("\"/App/notch-bridge\"") }
        XCTAssertEqual(ours.count, 1)

        let notif = hooks["Notification"] as! [[String: Any]]
        XCTAssertEqual(notif.count, 2)
    }

    func testPermissionRequestInstalledWhenDecisionsEnabled() throws {
        let url = tmpURL(); defer { remove(url) }
        try installer("/App/notch-bridge", decisions: true).install(into: url)
        let hooks = try read(url)["hooks"] as! [String: Any]
        let pr = hooks["PermissionRequest"] as! [[String: Any]]
        let matchers = pr.compactMap { $0["matcher"] as? String }.sorted()
        XCTAssertEqual(matchers, ["*", "ExitPlanMode"])
        for group in pr {
            let inner = (group["hooks"] as! [[String: Any]]).first { ($0["command"] as? String)?.hasPrefix("\"/App/notch-bridge\"") == true }!
            XCTAssertNil(inner["async"])
            XCTAssertEqual(inner["timeout"] as? Int, 600)
            XCTAssertEqual(inner["command"] as? String, "\"/App/notch-bridge\" --agent claude decide PermissionRequest")
        }
    }

    func testPermissionRequestOmittedWhenDecisionsDisabled() throws {
        let url = tmpURL(); defer { remove(url) }
        try installer("/App/notch-bridge", decisions: false).install(into: url)
        let hooks = try read(url)["hooks"] as! [String: Any]
        XCTAssertNil(hooks["PermissionRequest"])
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter HookInstallerTests`
Expected: FAIL — `cannot find 'ClaudeAgentProvider'` (defined in Task 8) and `HookInstaller(helperPath:specs:backupFilename:)` mismatch. This task creates the profile/installer types; `ClaudeAgentProvider` lands in Task 8, so this test file will finish compiling only after Task 8. Proceed to Step 3–4; the *installer* half is validated in Task 8's Step 4.

> Right-sizing note: Tasks 7 and 8 form one review boundary — the installer refactor and the Claude provider that supplies its profile compile together. Commit Task 7's non-test code now; the `HookInstallerTests` above is finalized and run green at the end of Task 8.

- [ ] **Step 3a: Create the profile types** — `Sources/ClaudeNotchCore/Agent/AgentInstallProfile.swift`:

```swift
import Foundation

/// One installed hook entry, agent-neutral. `args` is the argv appended after the quoted
/// helper path in the written command (e.g. "--agent claude SessionStart").
public struct HookSpec: Sendable {
    public let event: String
    public let matcher: String
    public let args: String
    public let isAsync: Bool
    public let timeout: Int?
    public init(event: String, matcher: String, args: String, isAsync: Bool, timeout: Int?) {
        self.event = event; self.matcher = matcher; self.args = args
        self.isAsync = isAsync; self.timeout = timeout
    }
}

/// A CLI version floor for enabling sync (decision) hooks. `binary` is run as
/// `/usr/bin/env <binary> --version`. Nil gate ⇒ decisions always enabled when present.
public struct VersionGate: Sendable {
    public let binary: String
    public let minVersion: (Int, Int, Int)
    public init(binary: String, minVersion: (Int, Int, Int)) {
        self.binary = binary; self.minVersion = minVersion
    }
}

/// Everything an agent needs to install its hooks: where, the backup name, the monitor and
/// decision hook specs, and an optional version gate for the decision specs.
public struct AgentInstallProfile: Sendable {
    public let settingsURL: URL
    public let backupFilename: String
    public let monitorSpecs: [HookSpec]
    public let decisionSpecs: [HookSpec]
    public let versionGate: VersionGate?
    public init(settingsURL: URL, backupFilename: String,
                monitorSpecs: [HookSpec], decisionSpecs: [HookSpec], versionGate: VersionGate?) {
        self.settingsURL = settingsURL; self.backupFilename = backupFilename
        self.monitorSpecs = monitorSpecs; self.decisionSpecs = decisionSpecs
        self.versionGate = versionGate
    }
}
```

- [ ] **Step 3b: Refactor `HookInstaller`** — replace the top of `HookInstaller.swift` (the `helperPath`/`decisionsEnabled`/`Spec`/`specs` section, lines 3–45) with an init that takes specs + backup name, and drop the private `Spec`/`specs`:

```swift
public struct HookInstaller {
    public let helperPath: String
    private let specs: [HookSpec]
    private let backupFilename: String

    public init(helperPath: String, specs: [HookSpec], backupFilename: String = "settings.json.claudenotch-backup") {
        self.helperPath = helperPath
        self.specs = specs
        self.backupFilename = backupFilename
    }
```

In `save(_:to:)`, replace the hardcoded backup name:

```swift
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent(backupFilename)
```

In `install(into:)`, the loop already iterates `specs` — it now iterates the injected `[HookSpec]`; the body that builds `ourHook` from `spec.event/matcher/args/isAsync/timeout` is unchanged. Confirm `command(args:)`, `isOurs`, `loadRoot`, `save`, `stripOurs`, `uninstall`, `status` are otherwise untouched.

- [ ] **Step 4: Build Core**

Run: `swift build --target ClaudeNotchCore`
Expected: PASS (Core compiles; `HookInstallerTests` compiles fully after Task 8).

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchCore/Agent/AgentInstallProfile.swift Sources/ClaudeNotchCore/Install/HookInstaller.swift Tests/ClaudeNotchCoreTests/HookInstallerTests.swift
git commit -m "refactor: drive HookInstaller from injected HookSpecs and AgentInstallProfile

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: `AgentProvider` + `AgentRegistry` + `ClaudeAgentProvider`

**Files:**
- Create: `Sources/ClaudeNotchCore/Agent/AgentProvider.swift`
- Create: `Sources/ClaudeNotchCore/Agent/AgentRegistry.swift`
- Create: `Sources/ClaudeNotchCore/Agent/ClaudeAgentProvider.swift`
- Test: `Tests/ClaudeNotchCoreTests/AgentRegistryTests.swift`

**Interfaces:**
- Consumes: all seam types (Tasks 2–7), `Paths.claudeSettingsURL`, `ClaudeToolRenderer`, `ClaudeDecisionMapper`, `ClaudeTranscriptParser`, `ClaudePricing`.
- Produces:
  - `protocol AgentProvider: Sendable { var agentID, displayName: String; func isPresent() -> Bool; var installProfile: AgentInstallProfile; var eventMapper: HookEventMapping; var decisionMapper: DecisionMapping; var decisionEncoder: DecisionEncoding; var transcriptParser: TranscriptParsing; var costEstimator: CostEstimator; var toolRenderer: ToolRendering }`
  - `extension AgentProvider` default `eventMapper = DefaultHookEventMapper()`, `decisionEncoder = HookSpecificOutputEncoder()`.
  - `final class AgentRegistry { init(_:[AgentProvider]); static let default; func provider(for id: String) -> AgentProvider; func presentProviders() -> [AgentProvider] }` — `provider(for:)` returns the matching agent, else the Claude provider.
  - `struct ClaudeAgentProvider: AgentProvider` (`agentID = "claude"`).

- [ ] **Step 1: Write the failing tests** — create `Tests/ClaudeNotchCoreTests/AgentRegistryTests.swift`:

```swift
import XCTest
@testable import ClaudeNotchCore

/// Minimal fake proving the seam works without any real agent.
private struct FakeProvider: AgentProvider {
    let agentID: String
    var displayName: String { agentID }
    let present: Bool
    func isPresent() -> Bool { present }
    var installProfile: AgentInstallProfile {
        AgentInstallProfile(settingsURL: URL(fileURLWithPath: "/tmp/\(agentID).json"),
                            backupFilename: "b", monitorSpecs: [], decisionSpecs: [], versionGate: nil)
    }
    var decisionMapper: DecisionMapping { ClaudeDecisionMapper() }
    var transcriptParser: TranscriptParsing { ClaudeTranscriptParser() }
    var costEstimator: CostEstimator { ClaudePricing() }
    var toolRenderer: ToolRendering { ClaudeToolRenderer() }
}

final class AgentRegistryTests: XCTestCase {
    func testResolvesKnownAgent() {
        let reg = AgentRegistry([FakeProvider(agentID: "codex", present: true),
                                 ClaudeAgentProvider()])
        XCTAssertEqual(reg.provider(for: "codex").agentID, "codex")
        XCTAssertEqual(reg.provider(for: "claude").agentID, "claude")
    }

    func testUnknownOrMissingResolvesToClaude() {
        let reg = AgentRegistry([FakeProvider(agentID: "codex", present: true), ClaudeAgentProvider()])
        XCTAssertEqual(reg.provider(for: "gemini").agentID, "claude")
        XCTAssertEqual(reg.provider(for: "").agentID, "claude")
    }

    func testPresentProvidersFiltersByPresence() {
        let reg = AgentRegistry([FakeProvider(agentID: "codex", present: false), ClaudeAgentProvider()])
        XCTAssertEqual(reg.presentProviders().map(\.agentID), ["claude"])
    }

    func testDefaultProvidesSharedEncoderAndMapper() {
        // Parse-and-compare: DecisionEncoder doesn't sort keys, so byte-comparing two
        // independent serializations is nondeterministic. Assert semantic equality.
        let p = ClaudeAgentProvider()
        let a = (try? JSONSerialization.jsonObject(with: p.decisionEncoder.stdoutJSON(for: .allow(scope: .once))!)) as? NSDictionary
        let b = (try? JSONSerialization.jsonObject(with: DecisionEncoder.stdoutJSON(for: .allow(scope: .once))!)) as? NSDictionary
        XCTAssertEqual(a, b)
        XCTAssertNoThrow(try p.eventMapper.decode(Data(#"{"session_id":"s"}"#.utf8), name: .stop, now: Date()))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter AgentRegistryTests`
Expected: FAIL — `cannot find 'AgentProvider'` / `'AgentRegistry'` / `'ClaudeAgentProvider'`.

- [ ] **Step 3a: `AgentProvider.swift`:**

```swift
import Foundation

/// One AI agent's pluggable integration: how to install its hooks, decode its events,
/// map/encode decisions, parse its transcript, price it, and render its tools. Adding an
/// agent = one conformer + one line in `AgentRegistry.default`.
public protocol AgentProvider: Sendable {
    var agentID: String { get }
    var displayName: String { get }
    /// Whether this agent is installed on this machine (drives which agents we install hooks for).
    func isPresent() -> Bool
    var installProfile: AgentInstallProfile { get }
    var eventMapper: HookEventMapping { get }
    var decisionMapper: DecisionMapping { get }
    var decisionEncoder: DecisionEncoding { get }
    var transcriptParser: TranscriptParsing { get }
    var costEstimator: CostEstimator { get }
    var toolRenderer: ToolRendering { get }
}

public extension AgentProvider {
    // Shared defaults: Claude and Codex have byte-identical inbound field names and decision JSON.
    var eventMapper: HookEventMapping { DefaultHookEventMapper() }
    var decisionEncoder: DecisionEncoding { HookSpecificOutputEncoder() }
}
```

- [ ] **Step 3b: `AgentRegistry.swift`:**

```swift
import Foundation

/// Resolves the `AgentProvider` for an event's `agent_id`. A missing/unknown id falls back to
/// the Claude provider, so pre-existing installs (no `agent_id`) and unknown future agents fail safe.
public final class AgentRegistry {
    private let providers: [AgentProvider]
    private let fallback: AgentProvider

    public init(_ providers: [AgentProvider]) {
        precondition(providers.contains { $0.agentID == "claude" }, "registry must include a Claude provider")
        self.providers = providers
        self.fallback = providers.first { $0.agentID == "claude" }!
    }

    public static let `default` = AgentRegistry([
        ClaudeAgentProvider(),
        CodexAgentProvider(),   // added in Task 13
    ])

    public func provider(for id: String) -> AgentProvider {
        providers.first { $0.agentID == id } ?? fallback
    }

    /// Providers whose agent is installed on this machine — the set we install hooks for.
    public func presentProviders() -> [AgentProvider] {
        providers.filter { $0.isPresent() }
    }
}
```

> The `CodexAgentProvider()` reference in `.default` won't compile until Task 13. For Tasks 8–12, temporarily set `.default` to `AgentRegistry([ClaudeAgentProvider()])` and restore the two-line version in Task 13. (Task 13 Step notes this explicitly.)

- [ ] **Step 3c: `ClaudeAgentProvider.swift`:**

```swift
import Foundation

/// The Claude Code agent, extracted from the pre-seam code. Behavior is byte-identical to
/// what ClaudeNotch shipped before multi-agent support.
public struct ClaudeAgentProvider: AgentProvider {
    public init() {}
    public let agentID = "claude"
    public let displayName = "Claude Code"

    // Claude is the primary target; ClaudeNotch has always installed its hooks unconditionally.
    public func isPresent() -> Bool { true }

    public var installProfile: AgentInstallProfile {
        AgentInstallProfile(
            settingsURL: Paths.claudeSettingsURL,
            backupFilename: "settings.json.claudenotch-backup",
            monitorSpecs: [
                HookSpec(event: "SessionStart", matcher: "*", args: "--agent claude SessionStart", isAsync: true, timeout: nil),
                HookSpec(event: "PreToolUse", matcher: "*", args: "--agent claude PreToolUse", isAsync: true, timeout: nil),
                HookSpec(event: "Notification", matcher: "permission_prompt",
                         args: "--agent claude Notification permission_prompt", isAsync: true, timeout: nil),
                HookSpec(event: "Notification", matcher: "elicitation_dialog|agent_needs_input",
                         args: "--agent claude Notification needs_input", isAsync: true, timeout: nil),
                HookSpec(event: "Stop", matcher: "*", args: "--agent claude Stop", isAsync: true, timeout: nil),
                HookSpec(event: "StopFailure", matcher: "*", args: "--agent claude StopFailure", isAsync: true, timeout: nil),
                HookSpec(event: "SessionEnd", matcher: "*", args: "--agent claude SessionEnd", isAsync: true, timeout: nil),
            ],
            decisionSpecs: [
                HookSpec(event: "PermissionRequest", matcher: "*",
                         args: "--agent claude decide PermissionRequest", isAsync: false, timeout: 600),
                HookSpec(event: "PermissionRequest", matcher: "ExitPlanMode",
                         args: "--agent claude decide PermissionRequest", isAsync: false, timeout: 600),
                HookSpec(event: "PreToolUse", matcher: "AskUserQuestion",
                         args: "--agent claude decide PreToolUse", isAsync: false, timeout: 600),
            ],
            versionGate: VersionGate(binary: "claude", minVersion: (2, 1, 200))
        )
    }

    public var decisionMapper: DecisionMapping { ClaudeDecisionMapper(renderer: toolRenderer) }
    public var transcriptParser: TranscriptParsing { ClaudeTranscriptParser() }
    public var costEstimator: CostEstimator { ClaudePricing() }
    public var toolRenderer: ToolRendering { ClaudeToolRenderer() }
    // eventMapper + decisionEncoder come from the shared defaults in the AgentProvider extension.
}
```

- [ ] **Step 4: Run to verify it passes** (also completes Task 7's test file)

Run: `swift test --filter AgentRegistryTests` then `swift test --filter HookInstallerTests`
Expected: PASS both. (The Claude profile now embeds `--agent claude`, matching the `HookInstallerTests` assertion.)

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchCore/Agent/AgentProvider.swift Sources/ClaudeNotchCore/Agent/AgentRegistry.swift Sources/ClaudeNotchCore/Agent/ClaudeAgentProvider.swift Tests/ClaudeNotchCoreTests/AgentRegistryTests.swift
git commit -m "feat: add AgentProvider seam, AgentRegistry, and ClaudeAgentProvider

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Bridge `--agent <id>` parsing + inject `agent_id`

**Files:**
- Modify: `Sources/notch-bridge/main.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: bridge accepts `notch-bridge [--agent <id>] <Event> [subtype]` and `notch-bridge [--agent <id>] decide <Event>`; injects `payload["agent_id"] = id` (default `"claude"` when `--agent` absent).

- [ ] **Step 1: Implement** — in `main.swift`, replace the argv-parsing block (from `let args = CommandLine.arguments` through the `guard !eventName.isEmpty` line) with:

```swift
    var args = Array(CommandLine.arguments.dropFirst())   // drop program name
    guard !args.isEmpty else { exit(0) }

    // Optional leading "--agent <id>"; default "claude" for back-compat with old installs.
    var agentID = "claude"
    if args.first == "--agent", args.count >= 2 {
        agentID = args[1]
        args.removeFirst(2)
    }
    guard !args.isEmpty else { exit(0) }

    let isDecide = args[0] == "decide"
    let eventName = isDecide ? (args.count >= 2 ? args[1] : "") : args[0]
    let subtype: String? = isDecide ? nil : (args.count >= 2 ? args[1] : nil)
    guard !eventName.isEmpty else { exit(0) }
```

Then, in the payload-injection block, add the agent id next to the other injected keys:

```swift
    payload["env"] = envOut
    if let subtype { payload["matcher"] = subtype }
    payload["hook_event_name"] = eventName
    payload["agent_id"] = agentID
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: PASS (bridge target compiles).

- [ ] **Step 3: Manual smoke of arg parsing** (no app needed — verifies passthrough exit paths)

Run: `echo '{"session_id":"s1"}' | swift run notch-bridge --agent codex SessionStart; echo "exit=$?"`
Expected: `exit=0` and no output (app not running → passthrough). Repeat without `--agent`: `echo '{"session_id":"s1"}' | swift run notch-bridge Stop; echo "exit=$?"` → `exit=0`.

- [ ] **Step 4: Commit**

```bash
git add Sources/notch-bridge/main.swift
git commit -m "feat: parse --agent <id> in notch-bridge and inject agent_id into payload

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: `Session` rename + agent-aware `SessionStore.apply`

**Files:**
- Modify: `Sources/ClaudeNotchCore/Model/Session.swift`
- Modify: `Sources/ClaudeNotchCore/Domain/SessionStore.swift`
- Test: `Tests/ClaudeNotchCoreTests/SessionStoreTests.swift`

**Interfaces:**
- Consumes: `AgentProvider`, `ClaudeAgentProvider`, `ToolRendering`.
- Produces:
  - `Session.agentSessionID` (renamed from `claudeSessionID`) + new `Session.agentID: String`.
  - `SessionStore.apply(_ event: HookEvent, provider: AgentProvider) -> [SessionEffect]` — uses `provider.toolRenderer.actionLabel` and sets `agentID = provider.agentID`. (Old single-arg `apply` is removed.)

- [ ] **Step 1: Update the failing tests** — in `SessionStoreTests.swift`, add a provider and pass it to every `apply`. Change the top and each call:

Add after the `event(...)` helper:

```swift
    private let provider: AgentProvider = ClaudeAgentProvider()
```

Replace each `store.apply(event(...))` with `store.apply(event(...), provider: provider)`. Add one new test:

```swift
    func testSessionCarriesAgentID() {
        let store = SessionStore()
        _ = store.apply(event(.sessionStart), provider: provider)
        XCTAssertEqual(store.snapshot()[0].agentID, "claude")
        XCTAssertEqual(store.snapshot()[0].agentSessionID, "s1")
    }
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter SessionStoreTests`
Expected: FAIL — `apply(_:provider:)` not found / `agentID`/`agentSessionID` not found.

- [ ] **Step 3a: `Session.swift`** — rename the field and add `agentID`:

```swift
    public let key: String
    public var agentID: String
    public var agentSessionID: String
```

- [ ] **Step 3b: `SessionStore.swift`** — change `apply` to accept a provider, set `agentID`, and use the provider's renderer:

Replace the `apply` signature and the session-creation + preToolUse lines:

```swift
    @discardableResult
    public func apply(_ event: HookEvent, provider: AgentProvider) -> [SessionEffect] {
        let identity = identifiers.resolve(event.env)
        let k = SessionKey.derive(identity: identity, sessionID: event.sessionID)
        var s = sessions[k] ?? Session(
            key: k, agentID: provider.agentID, agentSessionID: event.sessionID, terminal: identity,
            cwd: event.cwd, title: title(fromCwd: event.cwd),
            state: .working, currentTool: nil, currentAction: nil,
            stateSince: event.receivedAt, usage: nil,
            startedAt: event.receivedAt, lastEventAt: event.receivedAt
        )
```

In the `.preToolUse` case, replace the action-label line:

```swift
            s.currentAction = provider.toolRenderer.actionLabel(toolName: event.toolName, input: event.toolInputDict)
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter SessionStoreTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchCore/Model/Session.swift Sources/ClaudeNotchCore/Domain/SessionStore.swift Tests/ClaudeNotchCoreTests/SessionStoreTests.swift
git commit -m "refactor: make Session agent-aware and route SessionStore.apply through a provider

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: Wire the App through the registry (HookServer + AppCoordinator)

**Files:**
- Modify: `Sources/ClaudeNotchApp/Transport/HookServer.swift`
- Modify: `Sources/ClaudeNotchApp/AppCoordinator.swift`

**Interfaces:**
- Consumes: `AgentRegistry`, `AgentProvider`, `HookEvent.peekAgentID`, `provider.eventMapper/decisionEncoder/decisionMapper/transcriptParser/costEstimator`, `SessionStore.apply(_:provider:)`, `UsageTracker.update(transcriptPath:parser:estimator:)`, `CLIVersion`.
- Produces: end of Phase A — the full app builds and behaves byte-identically for Claude, now routed through `AgentRegistry([ClaudeAgentProvider()])`.

- [ ] **Step 1: Update `HookServer`** to resolve a provider and use it for decode + decide-encode.

Add a stored registry and take it in `init`:

```swift
    private let agents: AgentRegistry
```

Change `init` to accept it (default `.default`):

```swift
    public init(token: String,
                agents: AgentRegistry = .default,
                onEvent: @escaping (HookEvent) -> Void,
                onDecision: ((HookEvent, @escaping (Decision) -> Void) -> Void)? = nil) {
        self.token = token
        self.agents = agents
        self.onEvent = onEvent
        self.onDecision = onDecision
    }
```

In `respond(...)`, replace the decode block (the `guard let name = ...` through the decide-branch encoder) with provider-routed logic:

```swift
        guard sentToken == token else { return write(conn, status: "401 Unauthorized", body: Data()) }
        guard let name = Self.eventName(fromPath: path) else {
            return write(conn, status: "400 Bad Request", body: Data())
        }
        let provider = agents.provider(for: HookEvent.peekAgentID(body))
        guard let event = try? provider.eventMapper.decode(body, name: name, now: Date()) else {
            return write(conn, status: "400 Bad Request", body: Data())
        }

        if path.hasPrefix("/decide/"), let onDecision {
            onDecision(event) { [weak self] decision in
                let body: Data
                if case let .answer(answers) = decision {
                    body = provider.decisionEncoder.answerStdoutJSON(answers, originalToolInput: event.toolInput) ?? Data()
                } else {
                    body = provider.decisionEncoder.stdoutJSON(for: decision) ?? Data()
                }
                self?.write(conn, status: "200 OK", body: body)
            }
        } else {
            onEvent(event)
            write(conn, status: "200 OK", body: Data())
        }
```

- [ ] **Step 2: Update `AppCoordinator`** — introduce the registry, install per present provider, route handling/usage/decisions through providers.

Replace the `usage` property (line 19) and add a registry:

```swift
    private let agents = AgentRegistry.default
    private let usage = UsageTracker(reader: FileTranscriptReader())
```

In `applicationDidFinishLaunching`, replace the `HookServer(...)` construction to pass the registry:

```swift
        let server = HookServer(
            token: token,
            agents: agents,
            onEvent: { [weak self] event in
                Task { @MainActor in self?.handle(event) }
            },
            onDecision: { [weak self] event, complete in
                guard let self else { return complete(.passthrough) }
                Task { await self.resolveDecision(event, complete) }
            })
```

Replace the hook-install block (step 3 in `applicationDidFinishLaunching`) with a per-present-provider loop:

```swift
        // 3. Install hooks (idempotent) for every present agent, pointing at the sibling helper.
        if let helper = helperPath() {
            installHooks(helper: helper)
        }
```

Add the helper methods (near `detectDecisionsSupported`), replacing `detectDecisionsSupported()`:

```swift
    private func installHooks(helper: String) {
        for provider in agents.presentProviders() {
            let profile = provider.installProfile
            let decisionsOn = decisionsEnabled(for: profile.versionGate)
            let specs = profile.monitorSpecs + (decisionsOn ? profile.decisionSpecs : [])
            try? HookInstaller(helperPath: helper, specs: specs, backupFilename: profile.backupFilename)
                .install(into: profile.settingsURL)
        }
    }

    private func uninstallHooks(helper: String) {
        for provider in agents.presentProviders() {
            let profile = provider.installProfile
            let specs = profile.monitorSpecs + profile.decisionSpecs
            try? HookInstaller(helperPath: helper, specs: specs, backupFilename: profile.backupFilename)
                .uninstall(from: profile.settingsURL)
        }
    }

    /// Nil gate ⇒ decisions always on (agent's hooks are ignored entirely if it's too old).
    private func decisionsEnabled(for gate: VersionGate?) -> Bool {
        guard let gate else { return true }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = [gate.binary, "--version"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run(); p.waitUntilExit() } catch { return false }
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return CLIVersion.meetsMinimum(out, gate.minVersion)
    }
```

Remove the now-unused `decisionsEnabled` stored `Bool` property (line 20) and the old `detectDecisionsSupported()` method.

Update `handle(_:)` to resolve the provider and pass it into `apply`/`usage`:

```swift
    private func handle(_ event: HookEvent) {
        let provider = agents.provider(for: event.agentID)
        let effects = store.apply(event, provider: provider)
        effects.forEach(sound.play)
        notch.update(store.snapshot())
        if event.name == .sessionEnd {
            let endKey = TerminalIdentifierRegistry.default.key(for: event.env, sessionID: event.sessionID)
            remembered.clear(sessionKey: endKey)
            if let path = event.transcriptPath, !path.isEmpty {
                Task { [weak self] in await self?.usage.forget(transcriptPath: path) }
            }
        }
        if event.name != .sessionEnd, let path = event.transcriptPath, !path.isEmpty {
            let key = TerminalIdentifierRegistry.default.key(for: event.env, sessionID: event.sessionID)
            Task { [weak self] in
                guard let self else { return }
                let u = await self.usage.update(transcriptPath: path,
                                                parser: provider.transcriptParser,
                                                estimator: provider.costEstimator)
                self.store.updateUsage(sessionKey: key, u)
                self.notch.update(self.store.snapshot())
            }
        }
    }
```

Update `resolveDecision(_:_:)` to use the provider's mapper (compute the sessionKey via the terminal registry, as before):

```swift
    private func resolveDecision(_ event: HookEvent, _ complete: @escaping (Decision) -> Void) async {
        let provider = agents.provider(for: event.agentID)
        if event.name == .permissionRequest, event.toolName == "AskUserQuestion" {
            return complete(.passthrough)
        }
        let sessionKey = TerminalIdentifierRegistry.default.key(for: event.env, sessionID: event.sessionID)
        guard let request = provider.decisionMapper.request(from: event, id: UUID().uuidString, sessionKey: sessionKey) else {
            return complete(.passthrough)
        }
        if case let .toolPermission(tool, _) = request.kind,
           remembered.isAllowed(sessionKey: request.sessionKey, tool: tool) {
            return complete(.allow(scope: .session))
        }
        let decision = await broker.decide(request)
        if case .allow(scope: .session) = decision,
           case let .toolPermission(tool, _) = request.kind {
            remembered.remember(sessionKey: request.sessionKey, tool: tool)
        }
        complete(decision)
    }
```

Update the menu-bar actions `reinstall()`/`uninstall()` to use the loops:

```swift
    @objc private func reinstall() {
        if let helper = helperPath() { installHooks(helper: helper) }
    }
    @objc private func uninstall() {
        if let helper = helperPath() { uninstallHooks(helper: helper) }
    }
```

- [ ] **Step 3: Build + full suite (Phase A complete)**

Run: `swift build && swift test`
Expected: PASS — app compiles; all Core tests green; Claude path unchanged.

- [ ] **Step 4: Manual regression (Claude)** — confirm byte-identical behavior:

Run: `swift run ClaudeNotchApp` (in one terminal), then run a Claude Code session in iTerm2/WezTerm/Kitty. Verify: session appears, states update (working/needs-permission/done), notch click jumps, permission allow/deny works in-place, usage/cost shows. Inspect `~/.claude/settings.json` — our commands now read `"…notch-bridge" --agent claude <event>`.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchApp/Transport/HookServer.swift Sources/ClaudeNotchApp/AppCoordinator.swift
git commit -m "refactor: route the app through AgentRegistry (Phase A seam complete)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase B — Codex adapter

### Task 12: Codex tool renderer, transcript parser, pricing, decision mapper

**Files:**
- Create: `Sources/ClaudeNotchCore/Agent/Codex/CodexToolRenderer.swift`
- Create: `Sources/ClaudeNotchCore/Agent/Codex/CodexTranscriptParser.swift`
- Create: `Sources/ClaudeNotchCore/Agent/Codex/OpenAIPricing.swift`
- Create: `Sources/ClaudeNotchCore/Agent/Codex/CodexDecisionMapper.swift`
- Test: `Tests/ClaudeNotchCoreTests/CodexTests.swift`

**Interfaces:**
- Consumes: `ToolRendering`, `TranscriptParsing`, `CostEstimator`, `DecisionMapping`, `ToolPreview`, `TokenUsage`.
- Produces: `CodexToolRenderer`, `CodexTranscriptParser`, `OpenAIPricing`, `CodexDecisionMapper` (all `public struct`, `init()` / `init(renderer:)`).

- [ ] **Step 1: Codex rollout schema — VERIFIED (open item #1 resolved).** Confirmed against 9 local rollouts (`~/.codex/sessions/**/*.jsonl`) + the `openai/codex` `protocol.rs` source. Each rollout line is `{"type","payload","timestamp"}`. **Model** = the `turn_context` payload's `model` (e.g. `"gpt-5-codex"`). **Usage** = `event_msg` payload with `type == "token_count"`, at `info.last_token_usage` (per-turn delta) — a `TokenUsage` with keys `input_tokens` (total input, includes cached), `cached_input_tokens`, `cache_write_input_tokens`, `output_tokens`, `reasoning_output_tokens`, `total_tokens`. Map to our four-bucket `TokenUsage`: `input = input_tokens − cached_input_tokens` (uncached), `output = output_tokens + reasoning_output_tokens`, `cacheRead = cached_input_tokens`, `cacheCreation = 0` (OpenAI has no cache-write charge). Accumulate `last_token_usage` across events (UsageTracker sums deltas). The parser + test in Step 3 reflect this verified schema.

- [ ] **Step 2: Write the failing tests** — create `Tests/ClaudeNotchCoreTests/CodexTests.swift`:

```swift
import XCTest
@testable import ClaudeNotchCore

final class CodexTests: XCTestCase {
    func testCodexRendersShellAndPatch() {
        let r = CodexToolRenderer()
        XCTAssertEqual(r.render(tool: "Bash", input: ["command": "ls -la"]), .command("ls -la"))
        // Codex puts both Bash and apply_patch content under tool_input.command (per hooks doc).
        if case .diff = r.render(tool: "apply_patch", input: ["command": "*** Update File: a.swift\n-old\n+new"]) {} else {
            XCTFail("apply_patch should render as a diff")
        }
        if case .raw = r.render(tool: "mystery_tool", input: [:]) {} else { XCTFail("unknown → raw") }
    }

    func testCodexActionLabels() {
        let r = CodexToolRenderer()
        XCTAssertEqual(r.actionLabel(toolName: "apply_patch", input: ["command": "*** Update File: /x/a.swift\n+z"]), "Edit a.swift")
        XCTAssertEqual(r.actionLabel(toolName: "Bash", input: ["command": "go build\n./run"]), "Bash: go build")
    }

    func testCodexDecisionMapperIsToolPermissionOnly() {
        let mapper = CodexDecisionMapper()
        let ti = try! JSONSerialization.data(withJSONObject: ["command": "rm -rf x"])
        let e = HookEvent(name: .permissionRequest, agentID: "codex", sessionID: "s1", cwd: "/w",
                          matcher: "*", toolName: "Bash", transcriptPath: nil, env: HookEnv(),
                          toolInput: ti, receivedAt: Date(timeIntervalSince1970: 1))
        guard case let .toolPermission(tool, _)? = mapper.request(from: e, id: "r", sessionKey: "k")?.kind else {
            return XCTFail("expected toolPermission")
        }
        XCTAssertEqual(tool, "Bash")
    }

    func testOpenAIPricingKnownAndUnknown() {
        XCTAssertNotNil(OpenAIPricing().cost(model: "gpt-5-codex", tokens: TokenUsage(input: 1_000_000)))
        XCTAssertNil(OpenAIPricing().cost(model: "claude-opus-4-8", tokens: TokenUsage(input: 1)))
    }

    func testCodexTranscriptParserSumsUsageAndModel() {
        // Verified Codex rollout schema: {type,payload,timestamp}; model in turn_context.payload.model;
        // usage in event_msg payload type "token_count" -> info.last_token_usage.
        let chunk = """
        {"type":"turn_context","payload":{"model":"gpt-5-codex"},"timestamp":"t"}
        {"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":20,"cache_write_input_tokens":0,"output_tokens":50,"reasoning_output_tokens":10,"total_tokens":150},"last_token_usage":{"input_tokens":100,"cached_input_tokens":20,"cache_write_input_tokens":0,"output_tokens":50,"reasoning_output_tokens":10,"total_tokens":150},"model_context_window":272000}},"timestamp":"t"}
        """
        let (model, usage) = CodexTranscriptParser().parse(chunk)
        XCTAssertEqual(model, "gpt-5-codex")
        // uncached input = 100 - 20 = 80; output_tokens = 50 (already includes 10 reasoning); cacheRead = 20.
        XCTAssertEqual(usage, TokenUsage(input: 80, output: 50, cacheCreation: 0, cacheRead: 20))
    }
}
```

- [ ] **Step 3a: `CodexToolRenderer.swift`:**

```swift
import Foundation

/// Codex CLI's tool catalog: `Bash` (shell) → command, `apply_patch` → diff, else raw.
public struct CodexToolRenderer: ToolRendering {
    public init() {}

    public func render(tool: String, input: [String: Any]) -> ToolPreview {
        switch tool {
        case "Bash", "shell":
            return .command((input["command"] as? String) ?? "")
        case "apply_patch":
            // Codex delivers the patch body under tool_input.command (fallbacks kept for safety).
            let patch = (input["command"] as? String) ?? (input["patch"] as? String) ?? (input["input"] as? String) ?? ""
            let file = Self.patchedFile(patch)
            let lines = patch.split(separator: "\n", omittingEmptySubsequences: false).compactMap { raw -> DiffLine? in
                let s = String(raw)
                if s.hasPrefix("+") && !s.hasPrefix("+++") { return DiffLine(kind: .added, text: String(s.dropFirst())) }
                if s.hasPrefix("-") && !s.hasPrefix("---") { return DiffLine(kind: .removed, text: String(s.dropFirst())) }
                return nil
            }
            return lines.isEmpty ? .raw(patch.isEmpty ? tool : patch) : .diff(file: file, lines: lines)
        default:
            let name = (input["command"] as? String) ?? (input["file_path"] as? String) ?? tool
            return .raw(name)
        }
    }

    public func actionLabel(toolName: String?, input: [String: Any]?) -> String? {
        guard let tool = toolName else { return nil }
        let input = input ?? [:]
        switch tool {
        case "Bash", "shell":
            let cmd = (input["command"] as? String) ?? ""
            let firstLine = cmd.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? cmd
            return firstLine.isEmpty ? "Bash:" : "Bash: \(firstLine)"
        case "apply_patch":
            let file = Self.patchedFile((input["command"] as? String) ?? (input["patch"] as? String) ?? (input["input"] as? String) ?? "")
            return file.isEmpty ? "Edit" : "Edit \((file as NSString).lastPathComponent)"
        default:
            return tool
        }
    }

    /// Pull the first target path out of an apply_patch body ("*** Update File: <path>").
    static func patchedFile(_ patch: String) -> String {
        for line in patch.split(separator: "\n") {
            for marker in ["*** Update File: ", "*** Add File: ", "*** Delete File: "] where line.hasPrefix(marker) {
                return String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }
}
```

- [ ] **Step 3b: `CodexTranscriptParser.swift`** (tolerant; adjust keys per Step 1):

```swift
import Foundation

/// Parses Codex CLI rollout JSONL. Each line is `{"type","payload","timestamp"}`.
/// - model: the `turn_context` payload's `model` field.
/// - usage: each `event_msg` payload with `type == "token_count"` carries `info.last_token_usage`
///   (the per-turn delta). Codex/OpenAI buckets map onto our four-bucket TokenUsage as:
///   input = input_tokens − cached_input_tokens (uncached), output = output_tokens (which ALREADY
///   includes reasoning_output_tokens — do not add it again), cacheRead = cached_input_tokens,
///   cacheCreation = 0 (OpenAI has no cache-write charge). Summing last_token_usage across events
///   accumulates correctly via UsageTracker. Schema verified against ~/.codex rollouts + the
///   openai/codex protocol source (TokenUsage.blended_total = non_cached_input + output_tokens).
public struct CodexTranscriptParser: TranscriptParsing {
    public init() {}
    public func parse(_ chunk: String) -> (model: String?, usage: TokenUsage) {
        var model: String? = nil
        var total = TokenUsage()
        for line in chunk.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = line.data(using: .utf8),
                  let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let payload = obj["payload"] as? [String: Any] else { continue }
            if (obj["type"] as? String) == "turn_context", let m = payload["model"] as? String {
                model = m   // only turn_context carries the active model
            }
            if (payload["type"] as? String) == "token_count",
               let info = payload["info"] as? [String: Any],
               let last = info["last_token_usage"] as? [String: Any] {
                let input = (last["input_tokens"] as? Int) ?? 0
                let cached = (last["cached_input_tokens"] as? Int) ?? 0
                let output = (last["output_tokens"] as? Int) ?? 0   // already includes reasoning_output_tokens
                total = total + TokenUsage(
                    input: max(0, input - cached),      // uncached input (input_tokens includes cached)
                    output: output,
                    cacheCreation: 0,
                    cacheRead: cached
                )
            }
        }
        return (model, total)
    }
}
```

- [ ] **Step 3c: `OpenAIPricing.swift`** (verify values against current pricing):

```swift
import Foundation

/// OpenAI/Codex per-model pricing (USD per million tokens). No cache-write bucket; the discounted
/// cached-input rate maps to `cacheRead`. VERIFY rates + model ids against current OpenAI pricing.
public struct OpenAIPricing: CostEstimator {
    struct Price: Sendable { let input, output, cacheRead: Double }   // USD / MTok

    private static let table: [String: Price] = [
        "gpt-5-codex": Price(input: 1.25, output: 10, cacheRead: 0.125),
        "gpt-5":       Price(input: 1.25, output: 10, cacheRead: 0.125),
        "gpt-5-mini":  Price(input: 0.25, output: 2,  cacheRead: 0.025),
        "o4-mini":     Price(input: 1.1,  output: 4.4, cacheRead: 0.275),
    ]

    public init() {}

    public func cost(model: String?, tokens: TokenUsage) -> Double? {
        guard let model, let p = Self.match(model) else { return nil }
        func mtok(_ n: Int) -> Double { Double(n) / 1_000_000 }
        return mtok(tokens.input) * p.input
             + mtok(tokens.output) * p.output
             + mtok(tokens.cacheRead) * p.cacheRead
        // cacheCreation is always 0 for Codex (OpenAI has no cache-write charge).
    }

    private static func match(_ model: String) -> Price? {
        if let p = table[model] { return p }
        // Longest matching key wins — deterministic; avoids a variant like "gpt-5-mini-2026-xx"
        // prefix-matching both "gpt-5-mini" and "gpt-5" with hash-order-dependent results.
        return table.keys.sorted { $0.count > $1.count }.first(where: { model.hasPrefix($0) }).map { table[$0]! }
    }
}
```

- [ ] **Step 3d: `CodexDecisionMapper.swift`:**

```swift
import Foundation

/// Codex has no AskUserQuestion/ExitPlanMode tools, so every decision is a tool-permission card.
public struct CodexDecisionMapper: DecisionMapping {
    private let renderer: ToolRendering
    public init(renderer: ToolRendering = CodexToolRenderer()) { self.renderer = renderer }

    public func request(from event: HookEvent, id: String, sessionKey: String) -> DecisionRequest? {
        guard let tool = event.toolName else { return nil }
        let input = event.toolInputDict ?? [:]
        return DecisionRequest(id: id, sessionKey: sessionKey,
                               kind: .toolPermission(tool: tool, preview: renderer.render(tool: tool, input: input)),
                               receivedAt: event.receivedAt)
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter CodexTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchCore/Agent/Codex Tests/ClaudeNotchCoreTests/CodexTests.swift
git commit -m "feat: add Codex tool renderer, transcript parser, pricing, decision mapper

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 13: `CodexAgentProvider` + register + presence detection

**Files:**
- Create: `Sources/ClaudeNotchCore/Agent/Codex/CodexAgentProvider.swift`
- Create: `Sources/ClaudeNotchCore/Config/CodexPaths.swift`
- Modify: `Sources/ClaudeNotchCore/Agent/AgentRegistry.swift` (restore `CodexAgentProvider()` in `.default`)
- Test: `Tests/ClaudeNotchCoreTests/CodexProviderTests.swift`

**Interfaces:**
- Consumes: everything from Task 12, `AgentProvider`, `AgentInstallProfile`, `HookSpec`.
- Produces:
  - `enum CodexPaths { static var codexDir: URL; static var hooksURL: URL }` (`~/.codex`, `~/.codex/hooks.json`).
  - `struct CodexAgentProvider: AgentProvider` (`agentID = "codex"`, `isPresent()` = `~/.codex` exists, install profile → `~/.codex/hooks.json`, monitor hooks `isAsync:false` + short timeout, `versionGate: nil`, decision specs for `PreToolUse` `*` and `PermissionRequest` `*`).

- [ ] **Step 1: Write the failing tests** — create `Tests/ClaudeNotchCoreTests/CodexProviderTests.swift`:

```swift
import XCTest
@testable import ClaudeNotchCore

final class CodexProviderTests: XCTestCase {
    private let codex = CodexAgentProvider()

    func testIdentityAndDefaults() {
        XCTAssertEqual(codex.agentID, "codex")
        // Shared encoder: Codex must produce the SAME decision JSON as Claude. Parse-and-compare
        // (order-independent) since DecisionEncoder does not sort keys.
        let c = (try? JSONSerialization.jsonObject(with: codex.decisionEncoder.stdoutJSON(for: .deny(reason: "x"))!)) as? NSDictionary
        let k = (try? JSONSerialization.jsonObject(with: ClaudeAgentProvider().decisionEncoder.stdoutJSON(for: .deny(reason: "x"))!)) as? NSDictionary
        XCTAssertEqual(c, k)
    }

    func testInstallProfileTargetsCodexHooksJSON() {
        let p = codex.installProfile
        XCTAssertTrue(p.settingsURL.path.hasSuffix(".codex/hooks.json"))
        XCTAssertNil(p.versionGate)   // never gated: old Codex ignores hooks.json entirely
        // Monitor hooks must be synchronous (Codex ignores `async`) with a short timeout.
        for spec in p.monitorSpecs {
            XCTAssertFalse(spec.isAsync, "\(spec.event) monitor hook must not be async for Codex")
            XCTAssertNotNil(spec.timeout)
        }
        // Each command carries the codex agent tag.
        XCTAssertTrue(p.monitorSpecs.allSatisfy { $0.args.hasPrefix("--agent codex ") })
        XCTAssertTrue(p.decisionSpecs.allSatisfy { $0.args.contains("--agent codex decide ") })
    }

    func testInstallWritesCodexHooksToTempFile() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("codex-hooks-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url)
                try? FileManager.default.removeItem(at: url.deletingLastPathComponent().appendingPathComponent("hooks.json.claudenotch-backup")) }
        let p = codex.installProfile
        try HookInstaller(helperPath: "/App/notch-bridge",
                          specs: p.monitorSpecs + p.decisionSpecs,
                          backupFilename: p.backupFilename).install(into: url)
        let hooks = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        XCTAssertNotNil((hooks["hooks"] as! [String: Any])["PreToolUse"])
        XCTAssertNotNil((hooks["hooks"] as! [String: Any])["SessionStart"])
    }

    func testRegistryDefaultNowIncludesCodex() {
        XCTAssertEqual(AgentRegistry.default.provider(for: "codex").agentID, "codex")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter CodexProviderTests`
Expected: FAIL — `cannot find 'CodexAgentProvider'` / `'CodexPaths'`.

- [ ] **Step 3a: `CodexPaths.swift`:**

```swift
import Foundation

public enum CodexPaths {
    public static var codexDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }
    /// Codex reads the same {"hooks":{…}} JSON shape Claude uses, from ~/.codex/hooks.json.
    public static var hooksURL: URL { codexDir.appendingPathComponent("hooks.json") }
}
```

- [ ] **Step 3b: `CodexAgentProvider.swift`:**

```swift
import Foundation

/// The Codex CLI agent. Its hook contract mirrors Claude's (same event names, stdin fields,
/// and hookSpecificOutput decision envelope), so it reuses the shared decode + decision encoder
/// and differs only in install location, tool catalog, transcript schema, and pricing.
public struct CodexAgentProvider: AgentProvider {
    public init() {}
    public let agentID = "codex"
    public let displayName = "Codex CLI"

    /// Present when the user has a ~/.codex directory (Codex creates it on first run).
    public func isPresent() -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: CodexPaths.codexDir.path, isDirectory: &isDir) && isDir.boolValue
    }

    public var installProfile: AgentInstallProfile {
        // Codex ignores `async` (unsupported) → monitor hooks are synchronous with a short timeout;
        // the bridge POSTs-and-returns fast, so the CLI never stalls.
        AgentInstallProfile(
            settingsURL: CodexPaths.hooksURL,
            backupFilename: "hooks.json.claudenotch-backup",
            monitorSpecs: [
                HookSpec(event: "SessionStart", matcher: "*", args: "--agent codex SessionStart", isAsync: false, timeout: 5),
                HookSpec(event: "PreToolUse", matcher: "*", args: "--agent codex PreToolUse", isAsync: false, timeout: 5),
                HookSpec(event: "Stop", matcher: "*", args: "--agent codex Stop", isAsync: false, timeout: 5),
                HookSpec(event: "SessionEnd", matcher: "*", args: "--agent codex SessionEnd", isAsync: false, timeout: 3),
            ],
            decisionSpecs: [
                // Act-in-place goes through PermissionRequest (fires only when Codex wants approval),
                // NOT PreToolUse (which fires for EVERY tool call and would block them all).
                HookSpec(event: "PermissionRequest", matcher: "*",
                         args: "--agent codex decide PermissionRequest", isAsync: false, timeout: 600),
            ],
            versionGate: nil   // never gate: an old Codex without hook support ignores hooks.json entirely.
        )
    }

    public var decisionMapper: DecisionMapping { CodexDecisionMapper(renderer: toolRenderer) }
    public var transcriptParser: TranscriptParsing { CodexTranscriptParser() }
    public var costEstimator: CostEstimator { OpenAIPricing() }
    public var toolRenderer: ToolRendering { CodexToolRenderer() }
    // eventMapper + decisionEncoder come from the shared AgentProvider defaults.
}
```

- [ ] **Step 3c: Register Codex** — in `AgentRegistry.swift`, restore the two-provider default (undo the Task 8 temporary):

```swift
    public static let `default` = AgentRegistry([
        ClaudeAgentProvider(),
        CodexAgentProvider(),
    ])
```

> Note: Codex act-in-place uses `PermissionRequest *` for the decide hook (it fires only when Codex actually wants approval), mirroring Claude — NOT `PreToolUse *`, which fires on every tool call and would block them all. The `PreToolUse *` monitor hook (sync, short timeout, fire-and-return) is a different event and only updates the working state + tool label. If real e2e (Task 14) shows Codex never emits `PermissionRequest` and instead gates via `PreToolUse`, revisit this with a `PreToolUse`-deny-only approach.

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter CodexProviderTests` then `swift build && swift test`
Expected: PASS (full suite green; registry now has Codex).

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchCore/Agent/Codex/CodexAgentProvider.swift Sources/ClaudeNotchCore/Config/CodexPaths.swift Sources/ClaudeNotchCore/Agent/AgentRegistry.swift Tests/ClaudeNotchCoreTests/CodexProviderTests.swift
git commit -m "feat: add CodexAgentProvider and register it (Codex support complete)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 14: Manual end-to-end verification

**Files:** none (verification only). Record results in the spec's §15 or a short note.

- [ ] **Step 1: Build and launch**

Run: `swift build && swift run ClaudeNotchApp`
Expected: menu-bar `◗` appears; `~/.claude/settings.json` has `--agent claude` hooks; if `~/.codex` exists, `~/.codex/hooks.json` has `--agent codex` hooks.

- [ ] **Step 2: Claude regression** — run a Claude Code session; confirm glance states, jump, act-in-place allow/deny, and usage/cost are unchanged from before this branch.

- [ ] **Step 3: Codex monitoring + jump** — run a Codex CLI session; confirm it appears in the notch (working/done states), the row shows a Codex tool action label (`Bash:`/`Edit`), and clicking the row jumps to its terminal pane.

- [ ] **Step 4: Codex act-in-place** — trigger a Codex tool that needs approval; confirm the notch shows an allow/deny card and that allow proceeds / deny blocks in the Codex CLI.

- [ ] **Step 5: Codex usage/cost** — confirm token counts appear; if cost is missing, capture `~/.codex/.../*.jsonl` usage keys and adjust `CodexTranscriptParser`/`OpenAIPricing` (Task 12), then re-verify.

- [ ] **Step 6: Back-compat** — confirm an old-style hook command with no `--agent` still routes to Claude (temporarily add a `"…notch-bridge" Stop` hook by hand, fire it, confirm the session is attributed to Claude).

- [ ] **Step 7: Finalize** — update the design spec's open items with verified values (Codex rollout schema, OpenAI prices) and commit any parser/pricing corrections.

```bash
git add -A
git commit -m "docs: record Codex e2e verification and finalize transcript/pricing constants

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage** (each spec §/requirement → task):
- §1 seam over 11 edges → Tasks 1–13 (install 7/8/11; version 6; event vocab+decode 1/2; inbound fields 1/2; tool→decision 4/12; decision JSON 2; argv 9; transcript 5/12; pricing 5/12; tool-render 3/12; Session field 10).
- §4 shared defaults / unknown→Claude / TokenUsage superset / sync Codex hooks → Tasks 2, 8, 12/13.
- §5 architecture (routing on wire) → Tasks 9, 11.
- §7 agent routing/keying → Tasks 1, 9, 10, 11.
- §8 decision path (Codex toolPermission-only, shared encoder) → Tasks 4, 12, 13.
- §9 usage/cost per agent → Tasks 5, 11, 12.
- §10 Codex specifics → Tasks 12, 13.
- §11 error/edge (unknown id, codex absent, schema unknown, async ignored) → Tasks 8, 12, 13.
- §12 security (curated env unchanged, typed JSON) → no regression (bridge env forwarding untouched; Task 9 only adds `agent_id`).
- §14 extension recipe → realized by `AgentProvider` + `AgentRegistry.default` (Tasks 8, 13).
- Success criteria 1–5 → the seam (2,8), Claude byte-identical (all Phase-A `--filter`/regression steps), Codex parity (12,13,14), unknown→Claude (8), fake-provider seam test (8).

**2. Placeholder scan:** no "TBD"/"handle appropriately". The three open items are concrete, tolerant code with an explicit VERIFY step (Task 12 Step 1, Task 14). ✔

**3. Type consistency:** `apply(_:provider:)`, `update(transcriptPath:parser:estimator:)`, `scan(path:from:parser:)`, `request(from:id:sessionKey:)`, `decode(_:name:now:)`, `HookInstaller(helperPath:specs:backupFilename:)`, `AgentRegistry.provider(for:)`/`presentProviders()`, `CLIVersion`, `ClaudePricing`/`OpenAIPricing`, `HookServer(token:agents:onEvent:onDecision:)` — each defined once and used consistently across tasks. Cross-task ordering notes (DecisionRequest.from removed in T4 but App fixed in T11; `.default` temporary in T8 restored in T13) are called out inline.
