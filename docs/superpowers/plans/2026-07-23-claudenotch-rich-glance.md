# ClaudeNotch Rich Glance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enrich the expanded notch's per-session rows with project name, current action, time-in-state, model, tokens, and estimated cost (dense "Layout A"), and make clicking any row reliably jump to that terminal session.

**Architecture:** Three of the four data points already flow through v1 hooks (`cwd`, `toolName`/`toolInput`, event timestamps) and only need threading onto `Session` and into the row. Model/tokens/cost come from **read-only, incremental, offset-tracked** reads of the Claude Code transcript JSONL, parsed by a pure `TranscriptParser`, accumulated in a `UsageTracker` actor, and priced by a bundled `CostEstimator`. All new logic is pure/`Foundation`-only in `ClaudeNotchCore`; presentation/formatting lives in `ClaudeNotchApp`.

**Tech Stack:** Swift 6 toolchain (language mode v5), macOS 14+, SwiftUI + AppKit + DynamicNotchKit (App), `Foundation` only (Core). No new dependencies.

## Global Constraints

Every task's requirements implicitly include this section.

- **No new tests (project owner's standing rule).** Do NOT add new test cases, files, or methods on your own initiative. Only *update existing tests* where a signature change forces it. If a step seems to call for a new test, skip it. (This rule is flip-able only by explicit owner request; this plan assumes it stays in force.)
- **`ClaudeNotchCore` stays UI-free:** `Foundation` imports only. No `AppKit`/`SwiftUI` in Core. Formatters, colors, and friendly model names live in `ClaudeNotchApp`.
- **Contracts first / DI / pure domain / layered boundaries** — file I/O behind `TranscriptReading`; pricing behind `CostEstimator`; the async side effect isolated in the `UsageTracker` actor.
- **In-memory only.** Nothing (offsets, totals, usage) is persisted to disk. Transcript access is **read-only**.
- **Single external dependency** remains DynamicNotchKit; do not add packages.
- **Version floor:** macOS 14, `swift-tools-version: 6.0`, `swiftLanguageModes: [.v5]` (unchanged — do not edit `Package.swift`).
- **Git:** local only, nothing pushed. Conventional-commit messages, **no JIRA prefix** (project policy). Branch is `feat/claudenotch-v2-rich-glance`.
- **Verification per task:** `swift build` succeeds and `swift test` stays green (all existing tests pass, 0 failures).

## File Structure

**Create (Core, pure — `Foundation` only):**
- `Sources/ClaudeNotchCore/Model/TokenUsage.swift` — the four token buckets + accumulation.
- `Sources/ClaudeNotchCore/Model/SessionUsage.swift` — model + tokens + cost, per session.
- `Sources/ClaudeNotchCore/Domain/TranscriptParser.swift` — `TranscriptScan` + pure JSONL parser.
- `Sources/ClaudeNotchCore/Domain/TranscriptReader.swift` — `TranscriptReading` protocol + `FileTranscriptReader`.
- `Sources/ClaudeNotchCore/Domain/CostEstimator.swift` — `CostEstimator` protocol + `BundledPricing`.
- `Sources/ClaudeNotchCore/Domain/UsageTracker.swift` — actor: offsets + accumulation + estimate.

**Modify:**
- `Sources/ClaudeNotchCore/Model/Session.swift` — drop `model`; add `currentAction`, `stateSince`, `usage`, computed `projectName`.
- `Sources/ClaudeNotchCore/Domain/SessionStore.swift` — set `stateSince`/`currentAction` on `apply`; add `updateUsage`.
- `Sources/ClaudeNotchCore/Domain/ToolInputRenderer.swift` — add `actionLabel(...)`.
- `Sources/ClaudeNotchApp/AppCoordinator.swift` — drive `UsageTracker` off-main; surface `JumpResult`.
- `Sources/ClaudeNotchApp/UI/NotchViews.swift` — Layout A row (`SessionRow`), formatters, friendly model names, notice line, state color/label extensions.
- `Sources/ClaudeNotchApp/UI/NotchController.swift` — clock timer while visible; `showNotice`.
- `Sources/ClaudeNotchApp/Sound/SoundPlayer.swift` — `playError()`.
- `Tests/ClaudeNotchCoreTests/TerminalJumperRegistryTests.swift` — update the `Session(...)` constructor call (only test that constructs `Session` directly).

---

### Task 1: Value types (`TokenUsage`, `SessionUsage`) + `Session` fields

**Files:**
- Create: `Sources/ClaudeNotchCore/Model/TokenUsage.swift`
- Create: `Sources/ClaudeNotchCore/Model/SessionUsage.swift`
- Modify: `Sources/ClaudeNotchCore/Model/Session.swift` (remove `model` line 32; add fields + `projectName`)
- Modify: `Sources/ClaudeNotchCore/Domain/SessionStore.swift:21-25` (constructor call)
- Test: `Tests/ClaudeNotchCoreTests/TerminalJumperRegistryTests.swift:11-14` (constructor call)

**Interfaces:**
- Produces: `TokenUsage(input:output:cacheCreation:cacheRead:)` with `.total: Int` and `static func +`; `SessionUsage(model:tokens:costUSD:)`; `Session.currentAction: String?`, `Session.stateSince: Date`, `Session.usage: SessionUsage?`, `Session.projectName: String` (computed).

- [ ] **Step 1: Create `TokenUsage`**

```swift
// Sources/ClaudeNotchCore/Model/TokenUsage.swift
import Foundation

/// The four token buckets Claude Code reports per assistant turn in `message.usage`.
public struct TokenUsage: Sendable, Equatable {
    public var input: Int
    public var output: Int
    public var cacheCreation: Int
    public var cacheRead: Int

    public init(input: Int = 0, output: Int = 0, cacheCreation: Int = 0, cacheRead: Int = 0) {
        self.input = input
        self.output = output
        self.cacheCreation = cacheCreation
        self.cacheRead = cacheRead
    }

    public var total: Int { input + output + cacheCreation + cacheRead }

    public static func + (a: TokenUsage, b: TokenUsage) -> TokenUsage {
        TokenUsage(input: a.input + b.input,
                   output: a.output + b.output,
                   cacheCreation: a.cacheCreation + b.cacheCreation,
                   cacheRead: a.cacheRead + b.cacheRead)
    }
}
```

- [ ] **Step 2: Create `SessionUsage`**

```swift
// Sources/ClaudeNotchCore/Model/SessionUsage.swift
import Foundation

/// Model + accumulated tokens + estimated USD cost for a session, derived from its transcript.
public struct SessionUsage: Sendable, Equatable {
    public var model: String?      // raw id, e.g. "claude-opus-4-8"; nil until first assistant turn
    public var tokens: TokenUsage
    public var costUSD: Double?    // nil when the model price is unknown → render tokens only

    public init(model: String? = nil, tokens: TokenUsage = TokenUsage(), costUSD: Double? = nil) {
        self.model = model
        self.tokens = tokens
        self.costUSD = costUSD
    }
}
```

- [ ] **Step 3: Update `Session`** — replace the struct body (lines 25-37) with:

```swift
public struct Session: Identifiable, Sendable, Equatable {
    public var id: String { key }
    public let key: String
    public var claudeSessionID: String
    public var terminal: TerminalRef
    public var cwd: String
    public var title: String?
    public var state: SessionState
    public var currentTool: String?
    public var currentAction: String?      // human-readable, e.g. "Edit AppCoordinator.swift"
    public var stateSince: Date            // when `state` was last entered → time-in-state
    public var usage: SessionUsage?        // model + tokens + cost (nil until first transcript scan)
    public var startedAt: Date
    public var lastEventAt: Date

    /// Display name: the cwd's last path component, else the terminal name, else "session".
    public var projectName: String {
        let base = (cwd as NSString).lastPathComponent
        if !base.isEmpty, base != "/" { return base }
        if case let .other(termProgram, _) = terminal, let tp = termProgram, !tp.isEmpty {
            return tp.replacingOccurrences(of: ".app", with: "")
        }
        return "session"
    }
}
```

- [ ] **Step 4: Fix the `SessionStore` constructor call** — replace lines 21-25 with:

```swift
        var s = sessions[k] ?? Session(
            key: k, claudeSessionID: event.sessionID, terminal: .from(event.env),
            cwd: event.cwd, title: title(fromCwd: event.cwd),
            state: .working, currentTool: nil, currentAction: nil,
            stateSince: event.receivedAt, usage: nil,
            startedAt: event.receivedAt, lastEventAt: event.receivedAt
        )
```

- [ ] **Step 5: Fix the existing test's constructor call** — replace `TerminalJumperRegistryTests.swift` lines 11-14 with:

```swift
    private func session(_ term: TerminalRef) -> Session {
        Session(key: "k", claudeSessionID: "s", terminal: term, cwd: "/w", title: nil,
                state: .working, currentTool: nil, currentAction: nil,
                stateSince: .init(), usage: nil, startedAt: .init(), lastEventAt: .init())
    }
```

- [ ] **Step 6: Build**

Run: `swift build`
Expected: `Build complete!` (no errors)

- [ ] **Step 7: Test**

Run: `swift test`
Expected: all tests pass, 0 failures.

- [ ] **Step 8: Commit**

```bash
git add Sources/ClaudeNotchCore/Model/TokenUsage.swift \
        Sources/ClaudeNotchCore/Model/SessionUsage.swift \
        Sources/ClaudeNotchCore/Model/Session.swift \
        Sources/ClaudeNotchCore/Domain/SessionStore.swift \
        Tests/ClaudeNotchCoreTests/TerminalJumperRegistryTests.swift
git commit -m "feat: add TokenUsage/SessionUsage and session glance fields"
```

---

### Task 2: `ToolInputRenderer.actionLabel`

**Files:**
- Modify: `Sources/ClaudeNotchCore/Domain/ToolInputRenderer.swift` (add an extension method)

**Interfaces:**
- Consumes: nothing new.
- Produces: `ToolInputRenderer.actionLabel(toolName: String?, input: [String: Any]?) -> String?`

- [ ] **Step 1: Add `actionLabel`** — append to `ToolInputRenderer.swift` (after the closing brace of the enum, at end of file):

```swift
extension ToolInputRenderer {
    /// Short, human-readable label of what a tool call is doing, for the glance row.
    /// Returns nil when there is no tool.
    public static func actionLabel(toolName: String?, input: [String: Any]?) -> String? {
        guard let tool = toolName else { return nil }
        let input = input ?? [:]
        func base(_ key: String) -> String {
            guard let p = input[key] as? String, !p.isEmpty else { return "" }
            return (p as NSString).lastPathComponent
        }
        func labeled(_ verb: String, _ name: String) -> String {
            name.isEmpty ? verb : "\(verb) \(name)"
        }
        switch tool {
        case "Edit", "MultiEdit": return labeled("Edit", base("file_path"))
        case "Write":             return labeled("Write", base("file_path"))
        case "Read":              return labeled("Read", base("file_path"))
        case "Bash":
            let cmd = (input["command"] as? String) ?? ""
            let firstLine = cmd.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? cmd
            return labeled("Bash:", firstLine)
        case "Grep":         return labeled("Search", (input["pattern"] as? String) ?? "")
        case "Glob":         return labeled("Find", (input["pattern"] as? String) ?? "")
        case "Task":         return labeled("Task:", (input["description"] as? String) ?? "subagent")
        case "WebFetch":     return labeled("Fetch", (input["url"] as? String) ?? "")
        case "WebSearch":    return "Search web"
        case "ExitPlanMode": return "Review plan"
        default:             return tool
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Test**

Run: `swift test`
Expected: all tests pass, 0 failures (existing `ToolInputRendererTests` unaffected — `render` is unchanged).

- [ ] **Step 4: Commit**

```bash
git add Sources/ClaudeNotchCore/Domain/ToolInputRenderer.swift
git commit -m "feat: add ToolInputRenderer.actionLabel for glance rows"
```

---

### Task 3: `SessionStore` — set `stateSince`/`currentAction`, add `updateUsage`

**Files:**
- Modify: `Sources/ClaudeNotchCore/Domain/SessionStore.swift`

**Interfaces:**
- Consumes: `ToolInputRenderer.actionLabel(toolName:input:)` (Task 2); `SessionUsage` (Task 1).
- Produces: `SessionStore.updateUsage(sessionKey: String, _ usage: SessionUsage)`; `apply` now maintains `stateSince` and `currentAction`.

- [ ] **Step 1: Track state change + current action in `apply`** — replace the body from `s.lastEventAt = event.receivedAt` (line 26) through the end of the `switch` (line 56) with:

```swift
        s.lastEventAt = event.receivedAt
        if s.cwd.isEmpty { s.cwd = event.cwd }
        // Terminal is fixed at creation: sessions carrying an ITERM_SESSION_ID are keyed by the
        // iTerm UUID, so an `.other` session (keyed by the Claude session id) is never revisited
        // by a later iTerm-bearing event under the same key — an in-place upgrade can't occur.
        let previousState = s.state
        var effects: [SessionEffect] = []

        switch event.name {
        case .sessionStart:
            s.state = .working
        case .preToolUse:
            s.state = .working
            if let tool = event.toolName { s.currentTool = tool }
            s.currentAction = ToolInputRenderer.actionLabel(toolName: event.toolName, input: event.toolInputDict)
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

        if s.state != previousState { s.stateSince = event.receivedAt }
```

- [ ] **Step 2: Add `updateUsage`** — insert this method after `apply(...)` closes (after line 60, before `purge`):

```swift
    /// Merge fresh transcript-derived usage onto a session without altering its state.
    public func updateUsage(sessionKey: String, _ usage: SessionUsage) {
        guard var s = sessions[sessionKey] else { return }
        s.usage = usage
        sessions[sessionKey] = s
    }
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 4: Test**

Run: `swift test`
Expected: all tests pass, 0 failures (existing `SessionStoreTests` still assert `state`/`currentTool`/sort/purge — all preserved).

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchCore/Domain/SessionStore.swift
git commit -m "feat: track state-since and current action; add SessionStore.updateUsage"
```

---

### Task 4: `TranscriptParser` + `TranscriptScan`

**Files:**
- Create: `Sources/ClaudeNotchCore/Domain/TranscriptParser.swift`

**Interfaces:**
- Consumes: `TokenUsage` (Task 1).
- Produces: `TranscriptScan(newOffset:model:usageDelta:)`; `TranscriptParser.parse(_ chunk: String) -> (model: String?, usage: TokenUsage)`.

- [ ] **Step 1: Create the parser**

```swift
// Sources/ClaudeNotchCore/Domain/TranscriptParser.swift
import Foundation

/// The result of scanning newly-appended transcript bytes.
public struct TranscriptScan: Sendable, Equatable {
    public var newOffset: Int
    public var model: String?
    public var usageDelta: TokenUsage

    public init(newOffset: Int, model: String? = nil, usageDelta: TokenUsage = TokenUsage()) {
        self.newOffset = newOffset
        self.model = model
        self.usageDelta = usageDelta
    }
}

/// Pure parser for Claude Code transcript JSONL. Sums assistant `message.usage` token buckets
/// and reports the latest assistant `message.model`. Tolerant of unknown/malformed lines
/// (skips anything it can't read), matching `HookEvent.decode`'s posture.
///
/// Observed schema (Claude Code, 2026-07): each assistant line is
/// `{"type":"assistant","message":{"model":"claude-…","usage":{"input_tokens":…,
///  "output_tokens":…,"cache_creation_input_tokens":…,"cache_read_input_tokens":…}}}`.
public enum TranscriptParser {
    public static func parse(_ chunk: String) -> (model: String?, usage: TokenUsage) {
        var model: String? = nil
        var total = TokenUsage()
        for line in chunk.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = line.data(using: .utf8),
                  let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  (obj["type"] as? String) == "assistant",
                  let message = obj["message"] as? [String: Any] else { continue }
            if let m = message["model"] as? String { model = m }
            if let u = message["usage"] as? [String: Any] {
                total = total + TokenUsage(
                    input: (u["input_tokens"] as? Int) ?? 0,
                    output: (u["output_tokens"] as? Int) ?? 0,
                    cacheCreation: (u["cache_creation_input_tokens"] as? Int) ?? 0,
                    cacheRead: (u["cache_read_input_tokens"] as? Int) ?? 0
                )
            }
        }
        return (model, total)
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Test**

Run: `swift test`
Expected: all tests pass, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add Sources/ClaudeNotchCore/Domain/TranscriptParser.swift
git commit -m "feat: add pure TranscriptParser and TranscriptScan"
```

---

### Task 5: `TranscriptReading` + `FileTranscriptReader`

**Files:**
- Create: `Sources/ClaudeNotchCore/Domain/TranscriptReader.swift`

**Interfaces:**
- Consumes: `TranscriptParser.parse` + `TranscriptScan` (Task 4).
- Produces: `protocol TranscriptReading { func scan(path: String, from offset: Int) -> TranscriptScan }`; `struct FileTranscriptReader: TranscriptReading`.

**Note on correctness:** advance the offset only to the last complete newline in the read data, so a partial line that Claude is mid-writing is re-read (not lost) on the next scan.

- [ ] **Step 1: Create the reader**

```swift
// Sources/ClaudeNotchCore/Domain/TranscriptReader.swift
import Foundation

/// Reads newly-appended transcript bytes from a byte offset and parses them.
public protocol TranscriptReading: Sendable {
    func scan(path: String, from offset: Int) -> TranscriptScan
}

/// File-backed reader. Reads from `offset` to EOF; only consumes up to the last complete line
/// (a trailing partial line is left for the next scan). Resets to 0 if the file shrank
/// (rotation/truncation). Any I/O failure yields an empty delta and never throws to the caller.
public struct FileTranscriptReader: TranscriptReading {
    public init() {}

    public func scan(path: String, from offset: Int) -> TranscriptScan {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            return TranscriptScan(newOffset: offset)
        }
        defer { try? handle.close() }
        do {
            let size = Int(try handle.seekToEnd())
            var start = offset
            if start > size { start = 0 }                 // rotated/truncated → re-scan from top
            guard size > start else { return TranscriptScan(newOffset: start) }
            try handle.seek(toOffset: UInt64(start))
            let data = try handle.read(upToCount: size - start) ?? Data()
            guard let lastNL = data.lastIndex(of: 0x0A) else {
                return TranscriptScan(newOffset: start)   // no complete line yet
            }
            let complete = data[...lastNL]
            let consumed = start + complete.count
            let (model, usage) = TranscriptParser.parse(String(decoding: complete, as: UTF8.self))
            return TranscriptScan(newOffset: consumed, model: model, usageDelta: usage)
        } catch {
            return TranscriptScan(newOffset: offset)
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Test**

Run: `swift test`
Expected: all tests pass, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add Sources/ClaudeNotchCore/Domain/TranscriptReader.swift
git commit -m "feat: add TranscriptReading seam and FileTranscriptReader"
```

---

### Task 6: `CostEstimator` + `BundledPricing`

**Files:**
- Create: `Sources/ClaudeNotchCore/Domain/CostEstimator.swift`

**Interfaces:**
- Consumes: `TokenUsage` (Task 1).
- Produces: `protocol CostEstimator { func cost(model: String?, tokens: TokenUsage) -> Double? }`; `struct BundledPricing: CostEstimator`.

**Before implementing:** confirm current per-million-token (MTok) prices for the listed models against Anthropic's published pricing (the `claude-api` skill covers this). The values below are the standard published rates (Opus $15/$75, Sonnet $3/$15, Haiku $1/$5; cache-write = 1.25× input, cache-read = 0.1× input). Update any that have changed — an out-of-date row produces a wrong cost, not a crash.

- [ ] **Step 1: Create the estimator**

```swift
// Sources/ClaudeNotchCore/Domain/CostEstimator.swift
import Foundation

/// Estimates USD cost for token usage under a given model. Returns nil for unknown models.
public protocol CostEstimator: Sendable {
    func cost(model: String?, tokens: TokenUsage) -> Double?
}

/// Bundled per-model, per-bucket pricing (USD per million tokens).
/// Prices reflect Anthropic public pricing as of 2026-07 — verify and update when prices change.
public struct BundledPricing: CostEstimator {
    struct Price: Sendable { let input, output, cacheWrite, cacheRead: Double } // USD / MTok

    private static let table: [String: Price] = [
        "claude-opus-4-8":  Price(input: 15, output: 75, cacheWrite: 18.75, cacheRead: 1.5),
        "claude-opus-4-7":  Price(input: 15, output: 75, cacheWrite: 18.75, cacheRead: 1.5),
        "claude-sonnet-5":  Price(input: 3,  output: 15, cacheWrite: 3.75,  cacheRead: 0.3),
        "claude-haiku-4-5": Price(input: 1,  output: 5,  cacheWrite: 1.25,  cacheRead: 0.1),
        "claude-fable-5":   Price(input: 3,  output: 15, cacheWrite: 3.75,  cacheRead: 0.3),
    ]

    public init() {}

    public func cost(model: String?, tokens: TokenUsage) -> Double? {
        guard let model, let p = Self.match(model) else { return nil }
        func mtok(_ n: Int) -> Double { Double(n) / 1_000_000 }
        return mtok(tokens.input) * p.input
             + mtok(tokens.output) * p.output
             + mtok(tokens.cacheCreation) * p.cacheWrite
             + mtok(tokens.cacheRead) * p.cacheRead
    }

    /// Exact id match, else known-prefix match (ids sometimes carry a date/suffix).
    private static func match(_ model: String) -> Price? {
        if let p = table[model] { return p }
        return table.first(where: { model.hasPrefix($0.key) })?.value
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Test**

Run: `swift test`
Expected: all tests pass, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add Sources/ClaudeNotchCore/Domain/CostEstimator.swift
git commit -m "feat: add CostEstimator seam and BundledPricing table"
```

---

### Task 7: `UsageTracker` actor

**Files:**
- Create: `Sources/ClaudeNotchCore/Domain/UsageTracker.swift`

**Interfaces:**
- Consumes: `TranscriptReading` (Task 5), `CostEstimator` (Task 6), `TokenUsage`/`SessionUsage` (Task 1), `TranscriptScan` (Task 4).
- Produces: `actor UsageTracker { init(reader:estimator:); func update(transcriptPath: String) -> SessionUsage }`.

- [ ] **Step 1: Create the tracker**

```swift
// Sources/ClaudeNotchCore/Domain/UsageTracker.swift
import Foundation

/// Tracks per-transcript read offsets and accumulates token usage across incremental scans,
/// producing an up-to-date `SessionUsage` (with estimated cost) after each event.
/// Keyed by transcript path; serialized by the actor.
public actor UsageTracker {
    private struct Entry { var offset: Int; var totals: TokenUsage; var model: String? }
    private var entries: [String: Entry] = [:]
    private let reader: TranscriptReading
    private let estimator: CostEstimator

    public init(reader: TranscriptReading, estimator: CostEstimator) {
        self.reader = reader
        self.estimator = estimator
    }

    /// Incrementally read `transcriptPath`, accumulate totals, and return current usage.
    public func update(transcriptPath: String) -> SessionUsage {
        let previous = entries[transcriptPath] ?? Entry(offset: 0, totals: TokenUsage(), model: nil)
        let scan = reader.scan(path: transcriptPath, from: previous.offset)
        let entry: Entry
        if scan.newOffset < previous.offset {
            // rotated/truncated: reader re-scanned from the top → rebuild totals from this scan
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
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Test**

Run: `swift test`
Expected: all tests pass, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add Sources/ClaudeNotchCore/Domain/UsageTracker.swift
git commit -m "feat: add UsageTracker actor for incremental transcript usage"
```

---

### Task 8: Wire `UsageTracker` into `AppCoordinator`

**Files:**
- Modify: `Sources/ClaudeNotchApp/AppCoordinator.swift`

**Interfaces:**
- Consumes: `UsageTracker` (Task 7), `FileTranscriptReader` (Task 5), `BundledPricing` (Task 6), `SessionStore.updateUsage` (Task 3).
- Produces: usage populated on `Session` after each transcript-bearing event.

- [ ] **Step 1: Add the tracker property** — after line 18 (`private let remembered = RememberedDecisions()`), add:

```swift
    private let usage = UsageTracker(reader: FileTranscriptReader(), estimator: BundledPricing())
```

- [ ] **Step 2: Trigger an incremental scan on each transcript-bearing event** — replace `handle(_:)` (lines 76-83) with:

```swift
    private func handle(_ event: HookEvent) {
        let effects = store.apply(event)
        effects.forEach(sound.play)
        notch.update(store.snapshot())
        if event.name == .sessionEnd {
            remembered.clear(sessionKey: SessionKey.derive(env: event.env, sessionID: event.sessionID))
        }
        if let path = event.transcriptPath, !path.isEmpty {
            let key = SessionKey.derive(env: event.env, sessionID: event.sessionID)
            Task { [weak self] in
                guard let self else { return }
                let u = await self.usage.update(transcriptPath: path)   // off-main on the actor
                self.store.updateUsage(sessionKey: key, u)              // back on MainActor
                self.notch.update(self.store.snapshot())
            }
        }
    }
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: `Build complete!` (`Task {}` inside the `@MainActor` method inherits MainActor isolation; awaiting the actor hops off and resumes on main.)

- [ ] **Step 4: Test**

Run: `swift test`
Expected: all tests pass, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchApp/AppCoordinator.swift
git commit -m "feat: populate session usage from transcripts on each event"
```

---

### Task 9: Layout A row + formatters + clock timer

**Files:**
- Modify: `Sources/ClaudeNotchApp/UI/NotchViews.swift`
- Modify: `Sources/ClaudeNotchApp/UI/NotchController.swift`

**Interfaces:**
- Consumes: `Session.projectName`/`currentAction`/`stateSince`/`usage` (Tasks 1,3); `SessionUsage` (Task 1).
- Produces: `SessionRow` view; `Format`/`ModelName` helpers; `NotchViewModel.now`; `NotchController` clock.

- [ ] **Step 1: Add `now` to the view model** — in `NotchViews.swift`, replace the `NotchViewModel` class (lines 4-10) with:

```swift
@MainActor
final class NotchViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var pendingDecisions: [DecisionRequest] = []
    @Published var now: Date = Date()
    @Published var notice: String?
    var onJump: ((Session) -> Void)?
    var onDecide: ((DecisionRequest, Decision) -> Void)?
}
```

- [ ] **Step 2: Add state color/label + formatters + friendly model names** — in `NotchViews.swift`, immediately after the existing `extension SessionState { … }` block (after line 33), add:

```swift
extension SessionState {
    var dotColor: Color {
        switch self {
        case .needsPermission: return .orange
        case .needsInput: return .yellow
        case .working: return .blue
        case .done: return .green
        case .failed: return .red
        case .ended: return .gray
        }
    }
    var shortLabel: String {
        switch self {
        case .needsPermission, .needsInput: return "waiting"
        case .working: return "working"
        case .done: return "done"
        case .failed: return "failed"
        case .ended: return "ended"
        }
    }
}

enum ModelName {
    private static let map: [String: String] = [
        "claude-opus-4-8": "Opus 4.8", "claude-opus-4-7": "Opus 4.7",
        "claude-sonnet-5": "Sonnet 5", "claude-haiku-4-5": "Haiku 4.5",
        "claude-fable-5": "Fable 5",
    ]
    static func friendly(_ raw: String) -> String {
        if let f = map[raw] { return f }
        if let hit = map.first(where: { raw.hasPrefix($0.key) }) { return hit.value }
        return raw.replacingOccurrences(of: "claude-", with: "")
    }
}

enum Format {
    static func duration(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        let (h, m, sec) = (s / 3600, (s % 3600) / 60, s % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }
    static func tokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fk", Double(n) / 1_000) }
        return "\(n)"
    }
    static func usage(_ u: SessionUsage) -> String {
        let t = tokens(u.tokens.total)
        if let c = u.costUSD { return t + String(format: " · $%.2f", c) }
        return t
    }
}
```

- [ ] **Step 3: Add the `SessionRow` view** — in `NotchViews.swift`, add this new view (place it after `NotchExpandedView`):

```swift
struct SessionRow: View {
    let session: Session
    let now: Date

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(session.state.dotColor).frame(width: 8, height: 8).padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.projectName).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    if let model = session.usage?.model {
                        Text(ModelName.friendly(model)).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                if let action = session.currentAction ?? session.currentTool {
                    Text(action).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.state.shortLabel) \(Format.duration(now.timeIntervalSince(session.stateSince)))")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(session.state.dotColor)
                if let usage = session.usage, usage.tokens.total > 0 {
                    Text(Format.usage(usage)).font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())   // whole row is the click/hit target
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 4: Use `SessionRow` in the expanded list** — in `NotchExpandedView.body`, replace the `ForEach(vm.sessions) { s in … }` block (lines 45-59) with:

```swift
                ForEach(vm.sessions) { s in
                    Button { vm.onJump?(s) } label: { SessionRow(session: s, now: vm.now) }
                        .buttonStyle(.plain)
                }
```

- [ ] **Step 5: Widen the expanded frame for the denser row** — in `NotchExpandedView.body`, change `.frame(width: 320)` (line 63) to:

```swift
        .frame(width: 360)
```

- [ ] **Step 6: Drive the clock from `NotchController` while the notch is visible** — in `NotchController.swift`, add a `clock` property after `isPumping` (line 31):

```swift
    private var clock: Timer?
```

Then replace the `pump()` method's `switch target { … }` block (lines 62-68) with:

```swift
                switch target {
                case .hidden:   await self.notch?.hide();    self.stopClock()
                case .compact:  await self.notch?.compact(); self.startClock()
                case .expanded: await self.notch?.expand();  self.startClock()
                }
```

And add these two methods before the closing brace of `NotchController`:

```swift
    // The session rows show durations; DynamicNotchKit reveals the expanded view on hover even in
    // the compact state, so the clock runs whenever the notch is visible (not only force-expanded).
    private func startClock() {
        guard clock == nil else { return }
        clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.vm.now = Date() }
        }
    }
    private func stopClock() { clock?.invalidate(); clock = nil }
```

- [ ] **Step 7: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 8: Test**

Run: `swift test`
Expected: all tests pass, 0 failures.

- [ ] **Step 9: Commit**

```bash
git add Sources/ClaudeNotchApp/UI/NotchViews.swift Sources/ClaudeNotchApp/UI/NotchController.swift
git commit -m "feat: render Layout A glance rows with live time-in-state"
```

---

### Task 10: Surface jump results (reliable click-to-jump)

**Files:**
- Modify: `Sources/ClaudeNotchApp/Sound/SoundPlayer.swift`
- Modify: `Sources/ClaudeNotchApp/UI/NotchController.swift`
- Modify: `Sources/ClaudeNotchApp/UI/NotchViews.swift`
- Modify: `Sources/ClaudeNotchApp/AppCoordinator.swift`

**Interfaces:**
- Consumes: `JumpResult` (existing), `NotchViewModel.notice` (Task 9).
- Produces: `SoundPlayer.playError()`; `NotchController.showNotice(_:)`; a transient notice line in the expanded view; `onJump` that reacts to `.failed`.

- [ ] **Step 1: Add an error sound** — in `SoundPlayer.swift`, add after `play(_:)` (before the closing brace):

```swift
    /// A soft, distinct sound for a surfaced failure (e.g. a jump that couldn't land).
    public func playError() {
        guard enabled else { return }
        NSSound(named: "Funk")?.play()
    }
```

- [ ] **Step 2: Add `showNotice` to the controller** — in `NotchController.swift`, add a property after `clock` (from Task 9):

```swift
    private var noticeTimer: Timer?
```

And add this method next to `startClock`/`stopClock`:

```swift
    /// Show a transient notice in the expanded view for a few seconds (e.g. a failed jump).
    public func showNotice(_ text: String) {
        vm.notice = text
        noticeTimer?.invalidate()
        noticeTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.vm.notice = nil }
        }
    }
```

- [ ] **Step 3: Render the notice** — in `NotchViews.swift`, inside `NotchExpandedView.body`, add a notice line at the end of the outer `VStack` (after the `if let req … else { … }` block, still inside the VStack, before `.padding(12)`):

```swift
            if let notice = vm.notice {
                Text(notice).font(.system(size: 11)).foregroundStyle(.red)
            }
```

- [ ] **Step 4: React to the jump result** — in `AppCoordinator.swift`, replace the `notch.onJump = { … }` closure (lines 54-56) with:

```swift
        notch.onJump = { [weak self] session in
            Task { @MainActor in
                guard let self else { return }
                let result = await self.registry.jumper(for: session).jump(to: session)
                if case .failed = result {
                    self.sound.playError()
                    self.notch.showNotice("Couldn't focus that terminal window")
                }
            }
        }
```

- [ ] **Step 5: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 6: Test**

Run: `swift test`
Expected: all tests pass, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add Sources/ClaudeNotchApp/Sound/SoundPlayer.swift \
        Sources/ClaudeNotchApp/UI/NotchController.swift \
        Sources/ClaudeNotchApp/UI/NotchViews.swift \
        Sources/ClaudeNotchApp/AppCoordinator.swift
git commit -m "feat: surface failed terminal jumps with a sound and notice"
```

---

### Task 11: Manual end-to-end verification

**Files:** none (runtime verification).

This task has no automated tests by design (owner rule). Verify against real sessions.

- [ ] **Step 1: Build the app and helper**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 2: Run the app**

Run: `swift run ClaudeNotchApp`
Expected: menu-bar `◗` appears; no crash.

- [ ] **Step 3: Drive real sessions** — in two iTerm2 panes in different project folders, start `claude` and trigger a tool use (e.g. ask each to read a file). Hover the notch to expand.

Verify each row shows:
- correct **project name** (the folder basename, distinct per pane),
- a **current action** line (e.g. "Read …" / "Edit …"),
- a **time-in-state** clock that ticks (`working 0:03` → `0:04` …),
- **model** (e.g. "Opus 4.8") and **tokens · $cost** after the first assistant turn.

- [ ] **Step 4: Verify click-to-jump** — click a row; the exact iTerm2 pane is focused. Then quit iTerm and click a stale row; confirm the red notice ("Couldn't focus that terminal window") appears and the error sound plays.

- [ ] **Step 5: Record results** — append a short "Manual verification" note (what worked / any gaps) to this plan file or a `tasks/` note, and commit any doc update:

```bash
git add -A
git commit -m "docs: record rich-glance manual verification"
```

---

## Self-Review

**1. Spec coverage** (checked against `docs/superpowers/specs/2026-07-23-claudenotch-rich-glance-design.md`):
- §1 success criteria 1 (six data points, Layout A) → Tasks 1,3,9. Criterion 2 (reliable jump + surfaced failure) → Tasks 9 (`contentShape`), 10. Criterion 3 (incremental, bounded, no polling) → Tasks 4,5,7,8. Criterion 4 (bundled pricing, unknown→tokens-only) → Task 6 + `Format.usage`. Criterion 5 (graceful partial rows) → Tasks 5 (I/O never throws), 9 (optional-guarded row fields).
- §6 components → all created/modified (Tasks 1,2,4,5,6,7 + 3,8,9,10).
- §8 read/parse/tracker/pricing contracts → Tasks 4,5,6,7. §9 Layout A → Task 9. §10 jump table → Task 10. §11 formatting → Task 9. §12 edge cases → Tasks 5,7,9. §13 performance (offset + off-main + expand-only-ish clock) → Tasks 5,7,8,9.
- §16 testing (no new tests, flip-able) → encoded in Global Constraints + each task's verification.

**2. Placeholder scan:** No "TBD/TODO/handle edge cases" left; every code step contains complete code. The pricing NOTE in Task 6 is a real "verify current prices" instruction (a maintenance fact from spec §18), not a code placeholder, and ships with concrete default values.

**3. Type consistency:** `TokenUsage`/`SessionUsage` field names (`input/output/cacheCreation/cacheRead`, `model/tokens/costUSD`) are identical across Tasks 1,4,6,7,9. `TranscriptScan(newOffset:model:usageDelta:)` matches between Tasks 4,5,7. `UsageTracker.update(transcriptPath:)` matches Tasks 7,8. `SessionStore.updateUsage(sessionKey:_:)` matches Tasks 3,8. `Session` field set is consistent across Tasks 1,3,9 and the updated test in Task 1. `NotchViewModel.now`/`notice` defined in Task 9 and used in Tasks 9,10.
