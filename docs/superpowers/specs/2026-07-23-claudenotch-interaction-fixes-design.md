# ClaudeNotch — Notch Interaction Fixes (Hover Detail · AskUserQuestion Answer-in-Place · Terminal Jump)

**Date:** 2026-07-23
**Status:** Design — awaiting review
**Scope:** Single spec, three connected workstreams, sequenced **C → A → B**.

## Problem statement

Three defects/gaps in how the user interacts with the notch, discovered while testing parallel sessions:

1. **Hover shows no session detail (Issue A).** Hovering the compact notch only produces a slight height "zoom" and nothing else. The rich session rows (`NotchExpandedView`) exist but only render when the notch is force-expanded (i.e. when a decision is pending). The comment at `NotchController.swift:77` claims *"DynamicNotchKit reveals the expanded view on hover even in the compact state"* — this is **false**. `updateHoverState` (`DynamicNotch.swift:157`) only sets `isHovering` + haptics; `NotchView.swift:86` merely grows the compact content's height. Nothing flips `state` to `.expanded` on hover.

2. **AskUserQuestion shown as Allow/Deny (Issue B).** When Claude runs `AskUserQuestion`, the notch shows a generic `Permission · AskUserQuestion` card with Deny / Allow / Allow-for-session (`Decision.swift:33-37` funnels every non-`ExitPlanMode` tool into `.toolPermission`). Those buttons cannot answer a multiple-choice question — allow/deny only controls whether the tool runs. The user cannot answer from the notch.

3. **Nothing focuses the terminal (Issue C).** "Answer in terminal" calls `onDecide?(request, .passthrough)` (`NotchViews.swift:184`), which only resolves the broker — **no jump is wired into any decision-card button**. `onJump` (the AppleScript focus) is only attached to session rows (`AppCoordinator.swift:55`). So the terminal is never brought to front from a decision. This is the "not landing me on terminal" report.

C is the shared foundation: hover rows (A), the AskUserQuestion terminal fallback (B), and normal session rows all depend on a reliable jump.

## Verification (completed before design)

Empirically tested against **real interactive Claude Code v2.1.218** (tmux TTY), not just docs:

- A synchronous **PreToolUse** hook matched to `AskUserQuestion` that returns
  `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{…questions…,"answers":{"Pick a color":"Red"}}}}`
  caused Claude to render `User answered Claude's questions: Pick a color → Red` and continue — **the terminal menu never blocked**. Confirmed in interactive mode (the research agent's "-p-only" claim was wrong).
- The hook receives the full `tool_input`: `questions[].{question, header, options[].{label, description}, multiSelect}`. So the notch can render the *real* question + choices.
- **PreToolUse** is the correct fire point (fires in every permission mode). `PermissionRequest` only fired in normal (non-bypass) mode — which is why the screenshot showed a `Permission · AskUserQuestion` card. Building on PreToolUse is mode-robust.
- **Correction:** prior project memory ("AskUserQuestion cannot return sync decisions via hooks") is disproven and will be updated.

## Design

### Workstream C — Reliable terminal jump (build first)

**Goal:** any "go to the terminal" affordance actually focuses the right terminal, and failures are legible.

- **Session lookup by decision.** Add `SessionStore.session(forKey:) -> Session?`. A `DecisionRequest` carries `sessionKey`; the matching `Session` (with `TerminalRef`) already exists in the store (created by the async `SessionStart`/`PreToolUse` monitor hooks).
- **Wire jump into the decision path.** The notch's "Answer in terminal" action (and the AskUserQuestion terminal fallbacks in B) must focus the terminal. `AppCoordinator` maps `request.sessionKey → Session`, invokes the existing `TerminalJumperRegistry`, then resolves the broker with `.passthrough`. Reuse the existing failure handling (`sound.playError()` + `showNotice`).
- **C2 investigation (tmux + TCC).** The user runs Claude inside **tmux**. Two risks to confirm e2e and document:
  - `ITerm2Jumper` selects an iTerm session by UUID (`ITERM_SESSION_ID` suffix). Through tmux, that UUID focuses the *iTerm window/tab*, but not a specific tmux pane. Acceptable outcome: window-level focus reliably; tmux pane-precision is a documented limitation / stretch goal (`tmux select-window`/`select-pane`).
  - macOS **Automation (TCC)** permission must be granted for the app to script iTerm2; otherwise `executeAndReturnError` fails silently to `.failed`. Improve the failure notice to name Automation permission, and document granting it.

**C3 investigation outcome (2026-07-23):**
- Captured terminal identity in the owner's live session: `TERM_PROGRAM=iTerm.app`, `ITERM_SESSION_ID=w0t3p0:<uuid>`, and `$TMUX` **unset**. The bridge therefore captures a valid iTerm session id → `TerminalRef.iterm(uuid:)` → `ITerm2Jumper` precise AppleScript path. "teammate-mode tmux" does **not** strip `ITERM_SESSION_ID` here, so per-pane precision is available and no tmux-specific handling is needed for this setup.
- Root cause of "not landing on terminal": the missing jump wiring on the decision path (fixed in C2), not terminal mis-identification.
- Remaining dependency (human-pending e2e): macOS **Automation (TCC)** permission for `ClaudeNotchApp` → iTerm. If not granted, `NSAppleScript.executeAndReturnError` returns an error → `.failed` → the notch now shows *"Couldn't focus that terminal — check Automation permission"* + error sound (added in C2). Grant it on first jump and confirm focus.
- Known limitation (documented, not fixed): if Claude is ever run inside a real tmux server that strips `ITERM_SESSION_ID` (`$TMUX` set / `TERM_PROGRAM=tmux`), the session becomes `TerminalRef.other(termProgram:"tmux")` and `FallbackActivator` cannot resolve an app named "tmux" → jump fails. Follow-up if it arises: tmux-aware jump (`tmux select-window`/`select-pane` + activate the parent GUI terminal). Not needed for the current setup.

**Out of scope for C:** rewriting the jumpers or adding new terminal backends.

### Workstream A — Hover-to-expand session detail

**Goal:** hovering the notch reveals the existing rich rows after a short delay; leaving collapses back.

- **Hover as a presentation input.** `NotchController.presentation()` gains hover:
  `pending → .expanded` · `hovering + sessions → .expanded` · `sessions → .compact` · `else → .hidden`. (Always expands for ≥1 session — one consistent rule.)
- **Debounced hover bridge.** Subscribe to `notch.$isHovering` (Combine) in `init`. Enter timer **~0.30s**: if still hovering when it fires, set a private `isHovering = true` and `pump()`. Exit-grace timer **~0.25s**: if still not hovering, set `false` and `pump()`. The grace absorbs the hover blip when the panel grows under the cursor. Invalidate both timers alongside `clock`/`noticeTimer`. Correct the false comment at line 77.
- **No view changes** — `NotchExpandedView`/`SessionRow` already render everything and rows are already click-to-jump (now reliable via C).
- The library's small compact height "bump" on hover stays (it's `NotchView.swift:86`, not removable without forking); with expand chained after ~0.3s it reads as the start of the open animation.

### Workstream B — AskUserQuestion answer-in-place

**Goal:** the notch shows the real question and options; clicking one answers it without touching the terminal.

- **Hook install.** When `decisionsEnabled`, add a **synchronous PreToolUse hook matched to `AskUserQuestion`** → decide route (`HookInstaller` spec: `event PreToolUse`, `matcher AskUserQuestion`, `args "decide PreToolUse"`, `isAsync false`, `timeout 600`). The existing async `PreToolUse *` monitor stays (session working-state). The bridge already supports `decide <EventName>` → `/decide/PreToolUse` → `onDecision`.
- **Model.** New `DecisionKind.question(questions: [QuestionSpec])` where `QuestionSpec` is Sendable/Equatable `{ question, header, options: [{label, description}], multiSelect }`, parsed from `tool_input`. `DecisionRequest.from` special-cases `toolName == "AskUserQuestion"` → `.question(...)` (alongside the existing `ExitPlanMode` case).
- **Decision + encoder.** New `Decision.answer(answers: [String: [String]])` (question text → selected labels; internal general form). For the initial single-select scope the encoder emits each answer as a **string** (`{"Pick a color":"Red"}`) — the exact shape verified working; multiSelect (list form) is deferred to the terminal fallback, so list-encoding is a later concern. `DecisionEncoder` becomes event-aware — `stdoutJSON(for:event:toolInput:)`:
  - `PreToolUse` + `.answer` → `{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"allow", updatedInput: <original toolInput merged with answers>}}`. The encoder reconstructs `updatedInput` from the event's original `tool_input` (which HookServer already holds) + the answers map, so the full `questions[]` is preserved.
  - `PreToolUse` + `.passthrough` → nil (terminal menu shows).
  - `PermissionRequest` (unchanged) → current allow/deny envelope.
- **Avoid double-handling in normal mode.** In normal permission mode `PermissionRequest` may also fire for `AskUserQuestion`. The `PermissionRequest` decide path must return `.passthrough`/allow for `AskUserQuestion` so only the PreToolUse question card is shown (no stray allow/deny card).
- **UI.** New question card in `DecisionCardView`: render each question's `header`/`question` and one button per `option.label` (with `description` as subtext). Single-question single-select → one click answers. Plus an **"Answer in terminal"** button (uses C's jump) for the escape hatches.
- **Fallbacks → terminal (via C):** `multiSelect` questions, free-text ("Type something"), and "Chat about this" are not single-click buttons → route to "Answer in terminal". (multiSelect in-notch is a documented later enhancement.)

## Sequencing & dependencies

1. **C** — jump reliability (SessionStore lookup, decision-path jump wiring, tmux/TCC investigation). Foundation for A and B.
2. **A** — hover-to-expand (self-contained in `NotchController`; rows jump via C).
3. **B** — AskUserQuestion answer-in-place (hook + model + encoder + UI; terminal fallback via C).

## Edge cases & open checkpoints (verify during build)

- Normal-mode interaction of our PreToolUse `allow` with the existing `PermissionRequest *` decide hook — confirm no double-prompt (re-test with `/tmp/auq-verify` hook harness without `bypassPermissions`).
- Exact `answers` shape for `multiSelect` (single-select string confirmed working; list expected for multi).
- Multiple questions in one `AskUserQuestion` call — card must collect all before resolving.
- tmux pane precision vs window-level focus (C2).
- Hover debounce values (~0.30s / ~0.25s) tuned during e2e.

## Verification plan

- **C:** e2e — click a session row and a decision's "Answer in terminal"; confirm the correct iTerm window/tab focuses; confirm the failure notice when Automation permission is absent.
- **A:** e2e — with ≥1 active session, hover ~0.3s → rich rows appear; leave → collapse; a pending decision still force-expands immediately.
- **B:** e2e — trigger `AskUserQuestion`; notch shows the real question + option buttons; clicking answers it without terminal interaction; multiSelect/free-text fall back to terminal.
- Existing unit tests for `DecisionEncoder`/`Decision`/`SessionStore` updated for new cases (no new test files added unless requested).

## Out of scope

- New terminal backends or rewriting the AppleScript jumpers.
- In-notch multiSelect / free-text answering (terminal fallback for now).
- External-display notch support (tracked separately).
