# ClaudeNotch v2 — Rich Glance — Design Spec

- **Status:** Approved (design). Ready for implementation planning.
- **Date:** 2026-07-23
- **Builds on:** v1 (shipped, `1e02512`) and v2 act-in-place (shipped, `ed9a095`). See `docs/superpowers/specs/2026-07-22-claudenotch-design.md` and `…-v2-act-in-place-design.md`.
- **Repo policy:** Local git only. No remote, nothing pushed. No JIRA tracking for this project.

---

## 1. Purpose & goals

v1 lets you **glance and jump**; act-in-place lets you **decide** from the notch. Rich glance makes the glance itself carry its weight: when several sessions are open, the expanded notch should tell you — without clicking in — *which project each session is*, *what it's doing right now*, *how long it's been in that state*, and *which model it's on plus tokens/cost so far*.

This is the second v2 sub-project (v2 decomposition: act-in-place → **rich glance** → usage/cost → more agents → more terminals → SSH/mobile). It is additive and lower-risk: it introduces **no new hook contract**. Three of its four data points already flow through v1 hooks; only model/tokens/cost requires new read-only I/O against Claude Code's transcript files.

**Success criteria:**
1. Each row in the expanded notch shows: **project name · current action · time-in-state · model · tokens · cost**, in the approved dense two-line "Layout A".
2. Clicking any row reliably jumps to that exact terminal session; a failed jump is surfaced to the user rather than silently swallowed.
3. Model, token totals, and cost are read from the session's transcript with **incremental, bounded** work — no polling, no full re-parse per update, no UI stall.
4. Cost comes from a **bundled pricing table**; unknown/new models degrade gracefully to tokens-only (never a wrong number, never a crash).
5. Missing/unreadable transcript, empty `cwd`, or malformed data degrade to a partial row (project/action/time still shown) — never a hang or crash.

---

## 2. Scope & non-goals

**In scope:**
- Enriching the **expanded** per-session row with project name, current action, time-in-state, model, token totals, and estimated cost.
- A read-only, incremental **transcript reader** and a bundled **cost estimator**.
- Making the existing click-to-jump **surface its result** (fixes the currently-discarded `JumpResult`).

**Explicitly out of scope:**
- **Full usage/cost dashboard** (cross-session aggregates, history, budgets, rate-limit truth via OAuth/ccusage) — that is the separate bucket-C phase. Rich glance ships a deliberately *lightweight* per-session cost derived from the transcript; the `CostEstimator` seam lets that phase supersede it without touching callers.
- **Compact-pill changes** — the collapsed pill keeps v1's amber/blue counts. Rich glance only affects the expanded list.
- **Live per-token cost streaming** — usage updates at turn boundaries (when hooks fire), not continuously mid-response.
- More agents, more terminals, SSH/mobile (later phases).

---

## 3. Users & use case

Same single developer running parallel Claude Code sessions in iTerm2 on a notched Apple-Silicon MacBook. The new need: with 3–6 sessions open, the current row (glyph · title · state · tool) doesn't disambiguate "which repo is this" or "how long has this been stuck", and gives no sense of model/spend. Rich glance answers all four at a glance.

---

## 4. Data sources & key decisions

Grounded in direct inspection of a real transcript (`~/.claude/projects/<slug>/<session>.jsonl`) and the existing `HookEvent` decoder.

| Datum | Source | Availability |
|---|---|---|
| **Project name** | `cwd` basename | already decoded on `HookEvent.cwd` (v1) |
| **Current action** | `toolName` + `toolInput` | already captured (v1 + act-in-place); `ToolInputRenderer` exists |
| **Time-in-state** | `receivedAt` at last state change | already captured (v1) |
| **Model** | transcript assistant line `message.model` (e.g. `claude-opus-4-8`) | **new read-only I/O** |
| **Tokens** | transcript `message.usage` (`input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`) | **new read-only I/O** |
| **Cost** | tokens × bundled per-model, per-bucket price | **new logic** |

**Key decisions:**
- **Read the transcript incrementally, event-triggered.** Each session's transcript path arrives on every hook event (`transcript_path`). We keep a per-transcript byte offset, and on each event parse only the newly-appended lines, accumulating token totals and taking the model from the latest assistant line. No timer/polling; steady-state work is proportional to one turn's worth of appended JSONL. (One-time cost: the first scan of a transcript that predates the app reads it from offset 0 — accepted, and bounded to once per session.)
- **Bundled pricing table, priced per bucket.** Cache-read and cache-creation tokens are billed at different rates than input/output, and `message.usage` reports them separately, so the estimator prices the four buckets independently. Unknown model → `nil` cost → row shows tokens only.
- **No new hook contract.** Rich glance is pure enrichment over the existing monitoring hook stream plus read-only file access; the act-in-place synchronous decision path is untouched.

---

## 5. Architecture overview

Monitoring and decision flows are unchanged. Rich glance adds a read-only enrichment side-path off the existing event handling.

```
Monitoring event (v1, unchanged)
  Claude hook → notch-bridge → POST /hook/<event> → HookServer → AppCoordinator.onEvent
      │
      ├─► SessionStore.apply(event)      ── sets state, stateSince, currentAction, cwd
      │
      └─► if event.transcriptPath != nil:
             Task (off-main):
               UsageTracker.update(sessionKey, transcriptPath)   ── actor
                 → TranscriptReading.scan(path, from: offset)    ── incremental file read
                     → TranscriptParser.parse(chunk)             ── pure: latest model + usage delta
                 → merge delta into per-session totals
                 → CostEstimator.cost(model, totals)             ── bundled pricing
               returns SessionUsage
             → hop to @MainActor → SessionStore.updateUsage(sessionKey, usage) → NotchController.render
```

**Layering (unchanged discipline):** `AppCoordinator` (root) → transport (`HookServer`) → domain (`SessionStore`, `UsageTracker`, `TranscriptParser`, `BundledPricing` — all pure or DI-injected) → presentation (`NotchController` + views) + adapters (`TerminalJumperRegistry`, `SoundPlayer`). File I/O sits behind the `TranscriptReading` protocol; pricing behind `CostEstimator` — both fakeable seams.

---

## 6. Components & responsibilities

| Component | New/Mod | Layer | Purpose | Interface (sketch) |
|---|---|---|---|---|
| **TokenUsage** | new | domain (pure) | four token buckets + total | value type |
| **SessionUsage** | new | domain (pure) | `model?` + `TokenUsage` + `costUSD?` | value type |
| **TranscriptParser** | new | domain (pure) | parse a JSONL chunk → latest model + summed usage; tolerant of malformed lines | `parse(_ chunk:) -> (model:String?, usage:TokenUsage)` |
| **TranscriptReading** | new | domain (seam) | offset-tracked read of appended bytes → parsed scan | `scan(path:from:) throws -> TranscriptScan` |
| **FileTranscriptReader** | new | domain (I/O) | file-backed `TranscriptReading` (handles rotation/truncation) | conforms |
| **CostEstimator** | new | domain (seam) | tokens+model → USD, per bucket; `nil` for unknown | `cost(model:tokens:) -> Double?` |
| **BundledPricing** | new | domain | model-id → per-MTok prices (in/out/cache-write/cache-read) | conforms |
| **UsageTracker** | new | domain (actor) | per-transcript offsets + cumulative totals; injects reader + estimator | `update(sessionKey:transcriptPath:) -> SessionUsage?` |
| **ToolInputRenderer** `+actionLabel` | mod | domain (pure) | short human action label from tool+input | `actionLabel(toolName:input:) -> String?` |
| **Session** | mod | domain (pure) | add `cwd`, `stateSince`, `currentAction`, `usage`; fold in inert `model` | value type |
| **SessionStore** | mod | domain (pure) | set `stateSince`/`currentAction`/`cwd` on apply; `updateUsage(...)` | adds `updateUsage(sessionKey:_:)` |
| **AppCoordinator** | mod | root | drive `UsageTracker` on events; surface `JumpResult` | — |
| **NotchViews** (`NotchExpandedView`, `NotchViewModel`) | mod | presentation | Layout A row; formatters; friendly model names; expand-only clock timer | — |

`TranscriptParser`, `BundledPricing`, `ToolInputRenderer.actionLabel`, and `UsageTracker` (via a fake `TranscriptReading`) are the natural pure/seam test targets (see §16).

---

## 7. Data model

```swift
struct TokenUsage: Equatable, Sendable {
    var input: Int
    var output: Int
    var cacheCreation: Int
    var cacheRead: Int
    var total: Int { input + output + cacheCreation + cacheRead }
    static func + (a: TokenUsage, b: TokenUsage) -> TokenUsage   // accumulation
}

struct SessionUsage: Equatable, Sendable {
    var model: String?          // raw id, e.g. "claude-opus-4-8"
    var tokens: TokenUsage
    var costUSD: Double?        // nil when model price is unknown → render tokens only
}

struct TranscriptScan: Equatable, Sendable {
    var newOffset: Int          // resume point for the next incremental read
    var model: String?          // latest assistant model in this chunk (nil if none)
    var usageDelta: TokenUsage  // summed usage across new assistant lines
}
```

**`Session` gains** (folding in the previously-inert `model`):
```swift
var cwd: String                 // for projectName
var stateSince: Date            // when current SessionState was entered → time-in-state
var currentAction: String?      // e.g. "Edit AppCoordinator.swift"
var usage: SessionUsage?        // model + tokens + cost (nil until first transcript scan)
var projectName: String         // computed: cwd basename; empty cwd → terminal name, else "session" (§11)
```

**State-machine touch (no new states):** `SessionStore.apply` sets `stateSince` whenever `SessionState` changes, sets `currentAction` on `PreToolUse` (via `ToolInputRenderer.actionLabel`), and always records `cwd`. `updateUsage(sessionKey:_:)` merges a fresh `SessionUsage` onto the session without altering its state.

---

## 8. Transcript reading & pricing (the new I/O contract)

**Read contract (`TranscriptReading`):** given a path and a prior byte offset, seek to the offset, read to EOF, parse the appended JSONL, and return a `TranscriptScan`. Rotation/truncation guard: if the file is shorter than the stored offset, reset offset to 0 and re-scan. Any I/O error → return no delta (the row keeps its last known usage; never throws to the UI).

**Parser contract (`TranscriptParser`, pure):** iterate lines; for each JSON object where `type == "assistant"`, read `message.model` (→ latest model) and sum `message.usage.{input_tokens, output_tokens, cache_creation_input_tokens, cache_read_input_tokens}`. Non-assistant lines, unknown fields, and unparseable lines are skipped (same tolerance posture as `HookEvent.decode`).

**Tracker contract (`UsageTracker`, actor):** holds `[transcriptPath: (offset:Int, totals:TokenUsage, model:String?)]`. `update` runs a scan, accumulates `totals = totals + delta`, updates `model` if the scan saw one, computes `costUSD = estimator.cost(model:totals:)`, and returns the resulting `SessionUsage`. Serialized by the actor; safe under concurrent events.

**Pricing (`BundledPricing`):** a static map of model-id → per-million-token USD prices for the four buckets, covering current Claude models (Opus 4.8/4.7, Sonnet 5, Haiku 4.5, Fable 5), with a code comment citing the pricing source and date. `cost = Σ(bucketTokens/1_000_000 × bucketPrice)`. Unknown model → `nil`.

---

## 9. Notch UX (Layout A — dense two-line row)

Approved layout (validated in the visual companion). Per row:

```
● claude-notch          Opus 4.8            waiting 0:45
  Edit AppCoordinator.swift                 12.3k · $0.14
```

- **Line 1:** state dot (existing state color) · **project name** (bold) · **model** (dim, friendly name) — with **time-in-state** right-aligned, colored by state ("waiting …" amber/yellow, "working …" blue).
- **Line 2:** **current action** (truncates with ellipsis) — with **tokens · cost** right-aligned and dim.
- **Whole row is one click target** → jump to that terminal session (see §10).
- The compact pill is unchanged. A new attention event still auto-expands per v1.

---

## 10. Click-to-jump reliability

The row's entire surface is the hit target (not just the title). `AppCoordinator.onJump` stops discarding `JumpResult`:

| `JumpResult` | Behavior |
|---|---|
| `.jumped` | silent success |
| `.fellBack` | acceptable (app raised, exact pane not targeted) — no error |
| `.failed(reason)` | surface to user: soft error sound + brief row flash / inline "couldn't focus that window" |

This delivers the "clicking must land on that session" requirement honestly: when the precise jump can't happen, the user is told rather than left wondering.

---

## 11. Display & formatting rules

- **Friendly model names:** map raw ids → short labels (`claude-opus-4-8` → "Opus 4.8", `claude-sonnet-5` → "Sonnet 5", `claude-haiku-4-5-*` → "Haiku 4.5", `claude-fable-5` → "Fable 5"); unknown → strip `claude-` prefix, title-case.
- **Duration:** `0:45`, `2:10`, `1:04:00`; refreshed by a 1s timer that runs **only while the notch is expanded** (battery-friendly).
- **Tokens:** compact — `812`, `12.3k`, `1.2M`.
- **Cost:** `$0.14`, `$1.20`; hidden (not `$0.00`) until the first assistant turn produces usage; hidden entirely when model is unknown.
- **Project name:** `cwd` basename; empty `cwd` → terminal/app name fallback.

---

## 12. Error handling & edge cases

| Case | Handling |
|---|---|
| No transcript yet / unreadable | show project · action · time; leave model/tokens/cost blank; no crash |
| Transcript rotated or truncated (offset > size) | reset offset to 0, re-scan |
| Malformed / partial JSONL line | skip the line (tolerant parser) |
| Unknown / new model id | tokens shown, cost hidden (`nil`) |
| Empty `cwd` | fall back to terminal/app name for project label |
| Very long action string | truncate with ellipsis on line 2 |
| Model unknown until first assistant turn | model/cost blank briefly, fill in on next scan |
| Long pre-existing transcript (started before app) | one-time full read on first scan; incremental thereafter |

---

## 13. Performance

Steady-state work per event = parse only bytes appended since the last scan (≈ one turn of JSONL), off the main thread inside the `UsageTracker` actor. No polling. The only timer is the 1s clock refresh, active solely while expanded. Offsets and totals are small per-session state; nothing is written to disk.

---

## 14. Security & privacy

- Transcript reads are **local, read-only**; nothing is written back and no transcript content is transmitted (no external network, no telemetry — unchanged).
- Usage/cost/offset state is **in-memory only**; cleared with the session (reuses v1 GC / `SessionEnd`).
- Only token counts, model id, `cwd` basename, and a short action label are surfaced; no message content is rendered beyond the action label already derived from `tool_input` (as in act-in-place).
- Unchanged: unsandboxed with the Automation entitlement for iTerm control.

---

## 15. Coding standards & extensibility

- **Contracts first / DI / pure domain / layered boundaries** — unchanged. New pure types (`TokenUsage`, `SessionUsage`, `TranscriptParser`) have no I/O; file access and pricing are isolated behind `TranscriptReading` and `CostEstimator`; the async side effect lives in the `UsageTracker` actor at the domain edge, driven by the coordinator.
- The `CostEstimator` seam is the deliberate hook for the later usage/cost phase (swap `BundledPricing` for an OAuth/ccusage-backed estimator with no caller changes).
- `ToolInputRenderer` is extended (not duplicated) so permission cards and glance rows share one action/preview vocabulary.

---

## 16. Testing strategy

Per the project owner's standing rule — **no new test cases unless explicitly requested** — this increment adds no new tests on its own initiative. Existing tests are updated where signatures change (e.g., `Session` gaining fields ripples into `HookEventTests`/`SessionStoreTests` construction).

This is a **flip-able decision.** If tests are desired, the natural high-value targets are: `TranscriptParser` (usage summing + malformed-line tolerance, on a fixture JSONL), `BundledPricing` (per-bucket cost, unknown-model → nil), `ToolInputRenderer.actionLabel` (per-tool labels), and `UsageTracker` (offset accumulation + rotation reset, via a fake `TranscriptReading`). Say the word and these become plan tasks.

---

## 17. Build sequence (high-level; details go to the implementation plan)

1. **Data model:** `TokenUsage`, `SessionUsage`; extend `Session` (`cwd`, `stateSince`, `currentAction`, `usage`, `projectName`); `SessionStore` sets them on `apply` + `updateUsage(...)`.
2. **Action labels:** `ToolInputRenderer.actionLabel(toolName:input:)`.
3. **Transcript:** `TranscriptParser` (pure) + `TranscriptScan`; `TranscriptReading` protocol + `FileTranscriptReader` (offset, rotation guard).
4. **Pricing:** `CostEstimator` + `BundledPricing` (per-bucket, current models).
5. **Tracker:** `UsageTracker` actor (offsets, accumulation, estimate) with injected reader + estimator.
6. **Wiring:** `AppCoordinator` drives the tracker off-main on events with a `transcriptPath`; applies `updateUsage`; re-renders.
7. **UI:** rewrite `NotchExpandedView` to Layout A; add formatters, friendly model names, and the expand-only clock timer.
8. **Jump reliability:** surface `JumpResult` (`.failed` → sound + flash).
9. **Manual verification:** real multi-session run — confirm project/action/time/model/tokens/cost populate and rows jump.

---

## 18. Open questions / risks

- **Pricing drift** — the bundled table needs occasional updates; unknown models degrade to tokens-only. Accepted; the `CostEstimator` seam lets the usage/cost phase replace it wholesale.
- **Transcript schema stability** — `message.model` / `message.usage` field names are the integration contract; if Claude Code changes them, the parser degrades to "no usage" rather than crashing. Worth a comment pinning the observed schema/version.
- **Cache-bucket weighting** — cost accuracy depends on pricing cache-read/creation separately; must not lump them into input price.
- **First-scan cost for long transcripts** — a pre-existing multi-MB transcript incurs one full read; acceptable and one-time per session.
- **Action-label breadth** — first cut covers common tools (Edit/MultiEdit/Write/Bash/Read/Grep/Glob/Task/ExitPlanMode); others fall back to the raw tool name.
