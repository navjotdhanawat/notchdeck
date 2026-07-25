# ClaudeNotch v2 — Visual Polish (Notch UI Design System) — Design Spec

- **Status:** Approved (design). Ready for implementation planning.
- **Date:** 2026-07-24
- **Builds on:** v1 + v2 act-in-place + rich glance + multi-agent/multi-terminal, all shipped/merged to `main` (HEAD `250f03a`). See `docs/superpowers/specs/2026-07-22-claudenotch-v2-act-in-place-design.md` and the v2 mockups in `docs/mockups/`.
- **Repo policy:** Local git only. No remote, nothing pushed. No JIRA tracking for this project.

---

## 1. Purpose & goals

Every act-in-place / rich-glance *behavior* already ships and works end-to-end. What never caught up is the **look**: the live SwiftUI in `NotchViews.swift` is a plain first cut (flat cards, inline `.orange`/`.purple` literals, options rendered as un-pressable stacked text, a tiny "Answer in terminal"). The v2 mockup (`docs/mockups/claudenotch-v2-preview.html`) designed a far more polished surface that was never built.

This pass closes that gap: bring all four notch surfaces — **decision cards, glance rows, usage header, compact pill** — up to (and beyond) the mockup, so the notch **feels appealing and reads as one coherent system**. No behavior change, no new hook contracts, no new decision logic. Presentation layer only.

**Success criteria:**
1. The four surfaces share one visual language — a single accent-per-state palette, one card shell, one button/row/badge style — instead of ad-hoc inline styling.
2. AskUserQuestion options read as obviously pressable rows (index chip + label + description + hover/press), directly fixing the flat-text screenshot that triggered this work.
3. Permission cards show the tool + a properly styled diff (mono card, `+`/`-` coloring, diffstat), plan cards show a styled scrollable plan body, and both have clear ghost/primary action buttons.
4. Glance rows show state dot · title · colored activity line · agent + terminal badges · elapsed, with a subtle per-agent badge tint.
5. Nothing shown is dishonest: no ⌘-key chips that can't fire, no "$today" that isn't day-scoped, no fabricated data.
6. All existing tests stay green; the decision/answer wire behavior is byte-for-byte unchanged.

---

## 2. Scope & non-goals

**In scope (presentation only):**
- A small SwiftUI **design-system layer** (`NotchTheme` tokens + reusable component views).
- Rebuild of `DecisionCardView` (permission / ask / plan) on the design system, incl. a session-context strip (project · agent · terminal, via `request.sessionKey`).
- Rebuild of `SessionRow` (rich glance row) with badges + colored activity line.
- A new **usage header** summarizing tokens · cost across active sessions (honest label; from data we already track).
- Polished **compact pill** (crisp dots + counts, replacing emoji glyphs).

**Explicitly out of scope / non-goals:**
- **No new data plumbing.** The mockup's `You: <prompt>` row line is **dropped** — the mockup prompts were placeholder examples and there is no captured prompt to show; we will not add a `UserPromptSubmit` hook / `Session.userPrompt` for it. Rows use only fields that already exist.
- **No rate-limit bars.** The usage header shows tokens · cost only; the mockup's `5h`/`7d` rate-limit windows need a data source (ccusage/plan caps) we are not building here.
- **No global hotkeys.** The panel stays click-only and non-activating; the mockup's `⌘1–9` / `⌘Y` / `⌘N` chips become **numbered index chips** (visual only) and plain buttons.
- No changes to hooks, transport, `DecisionBroker`, `DecisionEncoder`, jump logic, agent/terminal seams, or any Core domain behavior.

---

## 3. Users & use case

Same single-developer, parallel-sessions, MacBook-notch context as v1/v2. The need here is purely qualitative: the surface the user stares at all day should be pleasant, scannable, and trustworthy — a decision card should make the choice obvious at a glance, and a row should say who/what/where without study.

---

## 4. Locked decisions

From the brainstorming pass (2026-07-24):

1. **Goal = implement the mockup, elevated** — the mockup direction is right; make it *feel appealing*, not a literal trace.
2. **All four surfaces** in scope (decision cards, glance rows, usage header, compact pill).
3. **Key chips = numbered index chips.** `1 / 2 / 3` as a visual, scannable index. No ⌘, no "press this key" promise. Options/buttons rely on clear hover + press affordances.
4. **Usage header = tokens · cost only**, aggregated from existing `SessionUsage`. No 5h/7d bars. Labeled for what it is (across active/tracked sessions), **not** "$today".
5. **`You:` prompt line = dropped** (no data source, no plumbing).
6. **needsInput = teal panel accent, but the state dot stays yellow 🟡** so the compact-pill dot legend stays consistent.
7. **Badges = subtle per-agent tint** (Claude / Codex / Gemini each a low-saturation tint); terminal badge neutral gray.
8. **Architecture = shared design-system layer** (Approach A), not inline styling.

---

## 5. Architecture — the design-system layer

Two new files under `Sources/ClaudeNotchApp/UI/`; everything else composes them.

### `NotchTheme.swift` — tokens (single source of truth)
- **`Accent`** — an enum of semantic accents each exposing `stroke: Color` and `softFill: Color`:
  - `permission` = amber, `question` = teal, `plan` = indigo, `working` = blue, `done` = green, `failed` = red, `neutral` = gray.
- **Mappings** (replace scattered literals):
  - `DecisionKind → Accent` (toolPermission→permission, question→question, planApproval→plan).
  - `SessionState → Accent` for surfaces (needsInput→question/teal), while `SessionState.dotColor` (existing) keeps needsInput = **yellow** for the dot/legend. The split is deliberate (locked decision #6).
- **Metrics** — corner radius, inner padding, hairline width, badge radius, row spacing — named constants so spacing is uniform.
- **Agent display** — `AgentBadgeStyle`: friendly name + tint keyed by `agentID` (`claude`, `codex`, `gemini`, fallback neutral). Mirrors the existing `ModelName` enum precedent; no dependency on Core beyond the `agentID` string.

### `NotchComponents.swift` — reusable views
- **`CardContainer<Content>`** — `.regularMaterial` background, themed corner radius + padding, hairline accent-tinted border. Every card sits in one.
- **`AccentStrip`** — `● <title>` colored top row + optional trailing slot (session-context badges).
- **`SessionContextStrip`** — project name + `Badge`(agent, tinted) + `Badge`(terminal, neutral); built from a `Session` looked up by `sessionKey`. Degrades gracefully when the session isn't found (project name omitted).
- **`IndexChip(Int)`** — the numbered `1/2/3` chip.
- **`OptionRow`** — index chip + label + optional description, full-width, `.contentShape(Rectangle())`, hover highlight + press state; calls an action.
- **`ActionButton`** — styles: `.ghost`, `.primary(Accent)`; consistent height/corner/press feedback.
- **`Badge`** — pill with text + tint (agent) or neutral (terminal/model).
- **`ActivityLine`** — one-line action text colored by `Accent` (blue working / green done / red failed / secondary otherwise).

All components are `View` structs with value inputs — independently previewable and unit-describable; no shared mutable state.

---

## 6. Surface designs

### 6.1 Decision cards (`DecisionCardView`, rebuilt)

Common frame for all three kinds inside `CardContainer`:
```
AccentStrip(kind)                         ● Permission · Edit
SessionContextStrip (project · agent · terminal)   middleware  [Claude] [iTerm]
── kind-specific body ──
[ action row ]
footer:  Answer in terminal            (N more waiting)
```
- **"Answer in terminal"** is promoted from a tiny caption to a clear ghost `ActionButton` in the footer (it's the universal escape hatch and the only path for multi-select / multi-question / free-text asks).

**Permission (amber):**
- Head: `⚠ <tool> · <file-or-target>`.
- Body: diff in a bordered mono card — `+` green / `-` red / context dimmed — plus a `+N −M` diffstat pill. Command/raw previews render in the same mono card. Reuse the existing `ToolPreview` cases (`.diff`/`.command`/`.raw`); scroll caps at ~150pt as today.
- Actions: `Deny` (ghost) · `Allow` (primary amber) · `Allow for session` (small secondary).

**Ask / needsInput (teal):**
- Single-select single-question path (unchanged logic): header chip (`q.header`) + question, then each option as an **`OptionRow`** (index chip + bold label + description). This is the direct fix for the screenshot.
- Non-single-select fallback (multiSelect / multi-question) keeps the current "answer in the terminal" message, now in the teal card frame.

**Plan (indigo):**
- Head: `Plan ready · <project>`.
- Body: the plan text (freeform markdown) in a themed scrollable mono/prose block with a subtle bottom fade when it overflows. **Note:** real plans are freeform text, so we style the block nicely rather than parse it into fake numbered "steps" (the mockup's numbered steps are illustrative).
- Actions: `Request changes` (ghost) · `Approve plan` (primary indigo).

### 6.2 Rich glance rows (`SessionRow`, rebuilt)
```
● fix auth bug            Opus 4.8              working 27m
  Writing middleware.ts…                  [Claude] [iTerm]
```
- Leading: `Circle().fill(state.dotColor)` (existing dot semantics; needsInput stays yellow).
- Title: `projectName` (+ friendly model as today).
- **`ActivityLine`**: `currentAction ?? currentTool`, colored by state (blue working / green done — "Done — click to jump" when done).
- Trailing: `state.shortLabel` + elapsed (`stateSince`), then **agent badge (tinted)** + **terminal badge (neutral)**, and token·cost when present.
- Whole row stays one click target → jump (unchanged `onJump`).

### 6.3 Usage header (`UsageHeader`, new)
- A slim strip at the top of the expanded list (only when ≥1 session has usage):
  `✦  1.2M tok · $2.14`  — `Σ` over `vm.sessions[].usage.tokens.total` and `.costUSD`.
- **Honest labeling:** this is "across active sessions," not a calendar-day total. No "today" wording unless day-bucketing is added later. Uses existing `Format.tokens` / cost formatting.
- Hidden entirely when a decision card is showing (the card owns the panel) and when there's no usage yet.

### 6.4 Compact pill (`NotchCompactView`, polished)
- Same counts/semantics (waiting = needsInput+needsPermission, working, done, failed).
- Replace emoji glyphs (`🟠`/`🔵`) with small `Circle().fill(accent)` + count for crisp, on-system rendering. Consistent spacing via theme metrics.

---

## 7. Data & model touchpoints

- **No Core model changes.** All inputs already exist: `DecisionRequest.sessionKey`, `Session.agentID`, `Session.terminal.appName`, `Session.state/currentAction/currentTool/stateSince`, `Session.usage`, `QuestionSpec`/`QuestionOption`, `ToolPreview`.
- `DecisionCardView` gains read access to the session list (via `NotchViewModel`) to resolve `sessionKey → Session` for the context strip. `NotchExpandedView` already holds `vm.sessions`; pass it (or a lookup closure) into the card. Missing lookup → context strip degrades (no crash).
- `NotchViewModel`, `NotchController`, `AppCoordinator` wiring unchanged except passing the session lookup into the card.

---

## 8. Testing

Per repo/global policy: **no new test cases added on our own initiative.** Existing tests must stay green (`swift build` 0 warnings, `swift test` currently 78/78).
- The rebuild is pure SwiftUI view code; existing Core/domain tests (decision encoding, session store, usage, pricing) are untouched and must continue to pass — this is the guardrail proving behavior didn't change.
- Views themselves aren't unit-tested (consistent with the current codebase, which has no SwiftUI view tests). Verification is the live GUI e2e pass (§10) plus the unchanged decision-wire tests.
- If any existing test references a view symbol we rename, update that reference (allowed — signature upkeep, not new cases).

---

## 9. Risks & mitigations

- **DynamicNotchKit overlay can't be screenshotted** (known: `screencapture` grabs empty). → Verify visually by eye on the real display; verify *behavior* via click outcomes and the unchanged wire tests.
- **Material/legibility on the notch** — `.regularMaterial` + accent borders must stay readable over the black notch and over bright wallpapers. → Tune fill opacities in the live e2e; keep text at current weights/sizes as a floor.
- **Panel width 360 / card width 360** — richer cards must not overflow vertically; keep diff/plan scroll caps (~150pt) and the fade. → Confirm the tallest realistic card (long diff + 3 buttons + footer) fits without clipping.
- **Scope creep back toward rate-limit/`You:`** — explicitly fenced out in §2; revisit only as separate increments.

---

## 10. Verification (human-pending GUI e2e)

Cannot run headless. After build: run `ClaudeNotchApp`, reinstall hooks, open real sessions, and confirm by eye:
1. AskUserQuestion card — options render as pressable index-chip rows; single-select click answers in place (behavior unchanged).
2. Permission card — tool + styled diff + diffstat; Deny/Allow/Allow-for-session work.
3. Plan card — styled scrollable plan body + fade; Approve / Request changes work.
4. Glance rows — dot · title · colored activity · tinted agent badge + neutral terminal badge · elapsed; click jumps.
5. Usage header — `N tok · $X` aggregate appears with usage, hidden with a card up.
6. Compact pill — crisp dots + counts.
7. needsInput — teal card, yellow dot.

---

## 11. File-level change map

- **New:** `Sources/ClaudeNotchApp/UI/NotchTheme.swift` (accents, mappings, metrics, agent badge style).
- **New:** `Sources/ClaudeNotchApp/UI/NotchComponents.swift` (`CardContainer`, `AccentStrip`, `SessionContextStrip`, `IndexChip`, `OptionRow`, `ActionButton`, `Badge`, `ActivityLine`).
- **Edit:** `Sources/ClaudeNotchApp/UI/NotchViews.swift` — rebuild `DecisionCardView`, `SessionRow`, `NotchCompactView`, `NotchExpandedView`; add `UsageHeader`; keep `NotchViewModel`, `Format`, `ModelName`, and `SessionState` extensions (extend, don't churn).
- **Edit (minimal):** `NotchController.swift` / `AppCoordinator.swift` only if needed to pass the session lookup into the decision card.
- **Untouched:** all of `ClaudeNotchCore`, transport, hooks, jump, agent/terminal seams, tests (except symbol-rename upkeep).

---

## 12. Implementation notes

- Build with the existing SDD flow (spec → plan → subagent tasks); coding subagents run on **opus** for this project (see memory `coding-tasks-use-opus`).
- Keep diffs additive and per-surface so each can be reviewed and eyeballed independently.
- Honesty is a hard requirement (§ success criterion 5): if a value can't be shown truthfully (rate limits, day-scoped cost, working key chips), it is not shown.
