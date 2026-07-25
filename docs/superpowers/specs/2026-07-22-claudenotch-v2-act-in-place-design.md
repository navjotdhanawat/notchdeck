# ClaudeNotch v2 — Act-in-place (Permission + Plan) — Design Spec

- **Status:** Approved (design). Ready for implementation planning.
- **Date:** 2026-07-22
- **Builds on:** v1 (shipped, merged to `main` at `1e02512`). See `docs/superpowers/specs/2026-07-22-claudenotch-design.md`.
- **Repo policy:** Local git only. No remote, nothing pushed. No JIRA tracking for this project.

---

## 1. Purpose & goals

v1 lets you **glance and jump**. v2 lets you **decide without leaving the notch**: when a Claude Code session blocks on a tool-permission request or a plan approval, the notch becomes the decision surface — you Allow/Deny (or Approve/Request-changes) with a click, and the choice is handed back to the waiting session. No jumping to the terminal to type `y`/`n`.

This is the first v2 sub-project (v2 as a whole was decomposed into: act-in-place → rich glance → usage/cost → more agents → more terminals → SSH/mobile). Act-in-place is the headline and the only piece that introduces the synchronous, decision-returning hook contract; everything else in v2 is additive and lower-risk.

**Success criteria:**
1. When a session raises a tool-permission request, the notch shows the tool + a diff/command and returns the user's Allow/Deny to Claude Code, bypassing the terminal prompt.
2. When a session finishes a plan (`ExitPlanMode`), the notch shows the plan and returns Approve/Request-changes.
3. Interaction never steals keyboard focus from the terminal (click-only).
4. **Every failure path degrades to Claude Code's normal terminal prompt — never a hang, never a silent wrong auto-answer.**
5. Setup remains one action (self-configures the new hooks); uninstall cleanly reverts; older Claude Code versions gracefully fall back to v1 monitor behavior.

---

## 2. Scope & non-goals

**In scope (true act-in-place):**
- **Tool permission** — approve/deny, with a diff (Edit/Write) or command (Bash) preview, plus "Allow for session".
- **Plan approval** — approve / request-changes on an `ExitPlanMode` plan.

**Explicitly out of scope for this spec:**
- **Answering `AskUserQuestion` in place.** Verified infeasible via hooks — there is no hook path to inject an answer (see §4). The "ask" surface stays v1 behavior: the notch shows *needs input* and you click to jump and answer in the terminal. (Competitors that answer it in place do so via brittle keystroke/accessibility injection; we decline that trade-off.)
- **Native-notification nudge** (a macOS notification when a decision is pending and you're focused elsewhere). Deferred to a later increment; the notch is always visible on the built-in display.
- **Keyboard / global-hotkey decisions.** First cut is click-only; ⌘Y/⌘N are shown as hints only. Global hotkeys are a later refinement.
- All other v2 phases: usage/cost, more agents (AgentAdapter), more terminals (TerminalJumper), SSH remote, mobile relay.

---

## 3. Users & use case

Same as v1: a single developer running parallel Claude Code sessions in iTerm2 (native splits/tabs) on an Apple-Silicon MacBook with a notch. The new need: when several sessions block on permissions at once, decide each from the notch instead of hunting for the right pane to type into.

---

## 4. Prior art & key decisions

Grounded in source-verified research of existing tools (see memory: `claudenotch-hook-decision-feasibility`, `claudenotch-act-in-place-prior-art`).

**Feasibility of returning a synchronous decision via hooks (Claude Code ≥ 2.1.200):**
- ✅ **Tool permission** — the `PermissionRequest` hook returns `hookSpecificOutput.decision.behavior = allow|deny` on stdout; it fires *only* when a permission dialog would appear, so it does not block routine tool calls.
- ✅ **Plan approval** — `PermissionRequest` with `matcher: "ExitPlanMode"` returns the same shape.
- ❌ **AskUserQuestion** — no hook can inject an answer; terminal-only. Hence out of scope.
- Hooks are **synchronous by default** (Claude blocks until the hook exits). Timeout default 600s (configurable); on timeout the tool is **denied**, so we respond with a passthrough well before the ceiling.

**Two architectural families (and why we pick one):**
- **Passive hook monitors** (attach to user-launched sessions via `settings.json`): vibe-notch and squawk both implement act-in-place with a **blocking `PermissionRequest` hook that returns the decision on stdout**. This is ClaudeNotch's model.
- **Launch-owned wrappers** (Happy, Omnara): richer decision channels (SDK `canUseTool`, `--permission-prompt-tool`, PTY) but they **spawn/wrap `claude`** — you run their CLI instead of `claude`. Incompatible with ClaudeNotch, which attaches to the iTerm2 sessions the user launches and never spawns `claude`.

**Decision: "Approach A" — a blocking `command` helper + `PermissionRequest` hook returning stdout JSON**, reusing v1's HTTP transport. This is both the documented standard for a passive monitor and the pattern proven by the two closest analogs. Refinements over the raw pattern: reuse v1's HTTP+token (not vibe-notch's Unix socket); no keystroke injection / no tmux dependency (vibe-notch leans on both); jump stays iTerm2 AppleScript (not yabai — no SIP changes).

---

## 5. Architecture overview

Two flows now coexist. Monitoring is v1, unchanged. The decision flow is new.

```
① Monitoring (v1 — fire-and-forget, unchanged)
   Claude hook (SessionStart/PreToolUse/Notification/Stop/StopFailure/SessionEnd)
     → notch-bridge  (async:true)  → POST /hook/<event> → 200 → SessionStore → notch pill/list

② Decision (v2 — synchronous, blocking)
   Claude PermissionRequest hook   [matcher "*" (tools) · matcher "ExitPlanMode" (plans) · synchronous]
     → notch-bridge decide          (reads stdin JSON + env ITERM_SESSION_ID; reads bridge.json)
          ├─ app NOT reachable? → print passthrough, exit 0 ─────────► normal terminal prompt
          └─ else POST /decide/<event>  ······ BLOCKS on HTTP response ······
                 → HookServer → DecisionBroker registers a PendingDecision
                 → SessionStore attaches it → NotchController auto-surfaces the card
                 → user clicks → broker resolves → HTTP response body = decision JSON
          ◄── helper reads response, prints decision JSON to stdout, exit 0 ──► Claude applies allow/deny
     (app-side timeout, or "Answer in terminal" → response = passthrough → normal terminal prompt)
```

**Layering (unchanged discipline):** `AppCoordinator` (composition root) → transport (`HookServer`, `DecisionBroker`) → domain (`SessionStore`, `Decision*`, `RememberedDecisions` — all pure) → presentation (`NotchController` + cards) + adapters (`TerminalJumper`, `SoundPlayer`, `HookInstaller`). The held continuation lives at the transport/coordinator seam, never in the pure domain.

---

## 6. Components & responsibilities

| Component | New/Mod | Layer | Purpose | Interface (sketch) |
|---|---|---|---|---|
| **Decision** | new | domain (pure) | value: `allow(scope)` / `deny(reason?)` / `passthrough`; `scope = once \| session` | value type |
| **DecisionRequest** | new | domain (pure) | parsed `/decide` payload | `id`, `sessionKey`, `kind` |
| **DecisionKind** | new | domain (pure) | `toolPermission(tool, input)` \| `planApproval(text)` | enum |
| **DecisionEncoder** | new | domain (pure) | `Decision` → exact `PermissionRequest` stdout JSON (the wire contract) | `encode(Decision, event) -> Data` |
| **ToolInputRenderer** | new | domain (pure) | `tool_input` → display model (Edit/MultiEdit → diff, Write → body, Bash → command) | `render([String:Any]) -> ToolPreview` |
| **RememberedDecisions** | new | domain (pure) | in-memory allow-for-session store; auto-answers matches | `remember(_:)`, `match(_:) -> Decision?`, `clear()` |
| **DecisionBroker** | new | transport/coord | holds in-flight decisions (`id → continuation`); owns app-side timeout | `await decision(for:) -> Decision`, `resolve(id:, Decision)` |
| **HookServer** `+/decide` | mod | transport | token-authed blocking endpoint; hands request to broker, holds response open | adds `POST /decide/<event>` |
| **notch-bridge** `+decide` | mod | helper | POST + block on response, print decision JSON, exit 0; passthrough on any error | `notch-bridge decide <event>` |
| **HookInstaller** | mod | adapter | register synchronous `PermissionRequest` hooks (`*` + `ExitPlanMode`); feature-detect `claude ≥ 2.1.200` | `install()`/`uninstall()`/`status()` |
| **SessionStore** | mod | domain (pure) | attach/clear a session's pending decision; new transitions | `apply(...)`, `attach(DecisionRequest)`, `clearDecision(id:)` |
| **NotchController** + **PermissionCard**/**PlanCard** | mod/new | presentation | render + auto-surface cards; route clicks to broker | `render(...)`, `onDecision: (id, Decision)->Void` |
| **AppCoordinator** | mod | root | wire broker ↔ server ↔ notch; inject timeout + RememberedDecisions | — |

`DecisionEncoder`, `ToolInputRenderer`, and `RememberedDecisions` are pure and independently testable — the primary new test targets.

---

## 7. Data model & state machine

```swift
enum AllowScope { case once, session }

enum Decision {
    case allow(scope: AllowScope)
    case deny(reason: String?)
    case passthrough            // emit nothing → Claude shows its normal prompt
}

enum DecisionKind {
    case toolPermission(tool: String, input: [String: Any])
    case planApproval(text: String)
}

struct DecisionRequest: Identifiable {
    let id: String              // unique per hook invocation
    let sessionKey: String      // same keying as v1 (ITERM_SESSION_ID suffix, else claude session_id)
    let kind: DecisionKind
    let receivedAt: Date
}
```

**Session state:** reuse v1's `SessionState` (`working, needsInput, needsPermission, done, failed, ended`). A session gains an optional pending `DecisionRequest` reference for rendering.

**New transitions (on top of v1's table):**

| Incoming | → State | Side effect |
|---|---|---|
| `PermissionRequest` (tool) received | needsPermission (+ attach DecisionRequest) | if `RememberedDecisions.match` → auto-resolve `allow`, don't surface; else surface card |
| `PermissionRequest` (`ExitPlanMode`) received | needsInput/needsPermission (+ attach) | surface plan card |
| Decision resolved (user or timeout) | working (clear pending) | broker writes response; card collapses |

---

## 8. Wire protocol & hook configuration

**Decision request** — helper POSTs to `POST /decide/<event>` with `X-ClaudeNotch-Token`, body assembled from hook stdin + env:
```json
{
  "hook_event_name": "PermissionRequest",
  "matcher": "*",
  "session_id": "abc123",
  "cwd": "/Users/you/project",
  "tool_name": "Edit",
  "tool_input": { "file_path": "…", "old_string": "…", "new_string": "…" },
  "env": { "ITERM_SESSION_ID": "w0t1p0:UUID", "TERM_PROGRAM": "iTerm.app" }
}
```

**Decision response / helper stdout** (the documented `PermissionRequest` contract):
```jsonc
// allow
{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}
// deny (optional message shown to Claude)
{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"Denied from notch"}}}
// passthrough → helper exits 0 emitting NOTHING → Claude shows its normal dialog
```

**Hooks written to `~/.claude/settings.json`** (marker-fenced, idempotent, atomic write + backup — v1 invariants). Monitoring hooks stay `async:true`; the new decision hooks are **synchronous** (no `async`) with a `timeout`:
```jsonc
{ "hooks": {
  "PermissionRequest": [
    { "matcher": "*",           "hooks": [{ "type":"command", "command":"<APP>/…/notch-bridge decide PermissionRequest", "timeout": 600 }] },
    { "matcher": "ExitPlanMode","hooks": [{ "type":"command", "command":"<APP>/…/notch-bridge decide PermissionRequest", "timeout": 600 }] }
  ]
  // …v1 monitoring hooks unchanged…
}}
```
- Registered only if `claude --version` ≥ 2.1.200 (feature detection); otherwise skipped, and v1 monitoring still works.
- `uninstall()` removes exactly our marker-fenced entries; pre-existing user hooks preserved.

---

## 9. Notch UX (decision cards)

Click-only, non-activating panel — never steals keyboard focus (v1 principle preserved; interaction model locked to click-only for the first cut).

- **Permission card** (amber accent): header `tool · target`; body = a **diff** for Edit/MultiEdit/Write (via `ToolInputRenderer`) or the **command** for Bash; buttons **Allow** / **Deny**; secondary **Allow for session**; **Answer in terminal** escape → `passthrough`. ⌘Y/⌘N rendered as hints only.
- **Plan card** (indigo accent): scrollable step list; **Approve** / **Request changes** (= `deny`, so Claude keeps planning); **Answer in terminal** → `passthrough`.
- A new pending decision **auto-expands** the notch; resolving collapses to the v1 pill.

---

## 10. Multiple pending decisions

Each blocked hook is an independent held request, resolvable in any order. The compact pill keeps v1's amber needs-permission count. The expanded panel surfaces the **newest** pending card with an "N more waiting" indicator; resolving advances to the next. No starvation: each pending decision is independently answerable or times out to passthrough.

---

## 11. Allow-for-session

"Allow for session" records `(sessionKey, tool)` in **RememberedDecisions**. The broker consults it *before* surfacing a card and auto-allows matches without UI. Scope: per-session-per-tool for the first cut (finer arg/path scoping is a later refinement). **In-memory only — never persisted to disk**; cleared on `SessionEnd`, app quit, or a menu-bar "Clear remembered approvals".

---

## 12. Fallback & timeout philosophy (fail-safe)

The cardinal rule from v1 — *the hook path must never degrade Claude Code* — governs every choice here. Every failure ends in Claude Code's **normal terminal prompt** (a safe, explicit human decision), never a hang or a silent auto-allow:

| Situation | Outcome |
|---|---|
| App not running / connect fails | helper prints passthrough immediately → normal prompt |
| User doesn't decide | app-side timeout (~5 min, below the 600s hook ceiling) → passthrough |
| User clicks "Answer in terminal" | passthrough on demand → normal prompt |
| App crashes while blocked | helper's own read timeout (< hook ceiling) → passthrough |

**Empirical unknown to confirm early in implementation:** that "passthrough = exit 0 emitting no decision" makes `PermissionRequest` show its normal dialog. This is the expected behavior (and is what makes app-down safety work). **If** a clean passthrough proves unsupported, the safe timeout fallback becomes `deny` (fail-closed) — this will be called out explicitly, never silently switched to auto-allow.

---

## 13. Error handling & edge cases (extends v1's table)

| Case | Handling |
|---|---|
| Claude Code < 2.1.200 | act-in-place hooks not installed; v1 monitor works; surface a one-time note |
| Malformed / unrecognized `tool_input` | show raw input / command string; still Allow/Deny |
| Decision for an unknown session (started before install) | still handled (cwd-derived title); decision returns regardless of jump |
| Pane closed before deciding | decision still returns to Claude; only the *jump* may fail (v1 fallback) |
| Duplicate/rapid decisions from one session | queued independently |
| Token mismatch on `/decide` | 401; helper treats as unreachable → passthrough |

---

## 14. Security & privacy

- `/decide` is **token-gated** exactly like `/hook`, 127.0.0.1-only. Higher stakes than v1: a spoofed decision could auto-approve a tool, so the per-launch bridge token is load-bearing.
- **Passthrough-on-any-error** ensures spoof attempts / malformed payloads / faults degrade to the normal terminal prompt, never a silent auto-allow.
- Remembered approvals live in memory only; no allowlist is written to disk.
- No external network, no telemetry (unchanged from v1). Still unsandboxed with the Automation entitlement for iTerm control.

---

## 15. Feature detection & graceful degradation

At install/launch, run `claude --version`. If ≥ 2.1.200, register the `PermissionRequest` decision hooks. If older (or version unreadable), skip them and run as the v1 monitor, surfacing a brief note that act-in-place needs a newer Claude Code. Uninstall is unchanged (marker-scoped).

---

## 16. Coding standards & extensibility

- **Contracts first / DI / pure domain / layered boundaries** — unchanged from v1. New pure types (`Decision`, `DecisionEncoder`, `ToolInputRenderer`, `RememberedDecisions`) have no I/O; the `DecisionBroker` isolates the async-continuation side effect at the transport seam.
- **Value types + explicit contracts** for the wire (`DecisionRequest`/`Decision`); docstrings on public interfaces.
- The design keeps the door open for the deferred pieces (native-notification nudge, keyboard/global hotkeys, finer allow-scoping) as additive changes.

---

## 17. Testing strategy (test the seam; no speculative tests — same as v1)

- **DecisionEncoder** — `Decision` → exact stdout JSON for allow / deny / plan. Highest value (the contract).
- **ToolInputRenderer** — Edit/MultiEdit → diff lines; Write → body; Bash → command.
- **RememberedDecisions** — match / scope / clear.
- **SessionStore** — decision-received and decision-resolved transitions; auto-allow short-circuit.
- **Integration smoke** — synthetic `POST /decide` holds open; `resolve` returns the decision body; timeout returns passthrough (extends v1's curl smoke). Reuses v1 fakes.
- No new UI tests, no speculative cases unless explicitly requested.

---

## 18. Build sequence (high-level; details go to the implementation plan)

1. **Domain core + contract:** `Decision`, `DecisionRequest`/`Kind`, `DecisionEncoder` (+ tests), `ToolInputRenderer` (+ tests), `RememberedDecisions` (+ tests).
2. **Broker + transport:** `DecisionBroker` (continuations + timeout), `HookServer` `POST /decide` holding the response open; smoke via `curl`.
3. **Helper:** `notch-bridge decide` — block on response, print stdout JSON, passthrough on any error; end-to-end from a fake hook.
4. **Install:** `HookInstaller` registers synchronous `PermissionRequest` hooks (`*` + `ExitPlanMode`) with feature detection; fixture tests preserve user hooks.
5. **UI:** `PermissionCard` + `PlanCard`; auto-surface; click-to-resolve wired through the broker; `SessionStore` pending-decision rendering.
6. **Empirical passthrough check** (§12) + hardening: timeout tuning, multiple-pending queue, allow-for-session clear, edge cases.
7. **Manual multi-session act-in-place test** in iTerm2 (real permission + plan).

---

## 19. Open questions / risks

- **Passthrough semantics** (§12) — the one empirical unknown; verify early. Fallback = fail-closed `deny` if unsupported.
- **`ExitPlanMode` plan text shape** — confirm the plan content available in `tool_input` for rich rendering; degrade to a summary if not.
- **Allow-for-session scope** — per-session-per-tool first; finer arg/path scoping deferred.
- **Keyboard / global hotkeys** — deferred; click-only first. Revisit if mouse-only proves a flow break.
- **AskUserQuestion parity** — competitors answer it via keystroke/accessibility injection; deliberately declined for robustness. Revisit only if strongly desired.
- **Hook `timeout` interplay** — the app-side timeout (~300s) must stay comfortably below the per-hook `timeout` (600s) so we always respond (decision or passthrough) before Claude force-denies at the ceiling.
