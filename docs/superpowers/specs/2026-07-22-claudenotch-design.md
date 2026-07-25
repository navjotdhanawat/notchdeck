# ClaudeNotch — Design Spec (v1)

- **Status:** Approved (design). Ready for implementation planning.
- **Date:** 2026-07-22
- **Working title:** ClaudeNotch (rename-friendly; the name is not load-bearing)
- **Repo policy:** Local git only. No remote, nothing pushed. No JIRA tracking for this project.

---

## 1. Purpose & goals

A native macOS app that turns the MacBook notch into a live status monitor for **parallel Claude Code CLI sessions** — a focused, open, yabai-free take on "Vibe Island."

Primary user pain: running 4–6 Claude Code sessions across iTerm2 panes/tabs, you can't tell at a glance which one is blocked (permission/question) vs. working vs. done, so you either babysit or leave sessions idle. ClaudeNotch surfaces per-session state in the notch and lets one click jump to the exact pane.

**v1 success criteria:**
1. With N Claude Code sessions running in iTerm2, the notch shows each session's state (working / needs input / needs permission / done / failed) in real time.
2. Clicking a session in the notch raises the **exact** iTerm2 window→tab→split pane it runs in.
3. A completion sound plays when a session finishes (or fails).
4. Setup is one action (self-configures Claude Code hooks); uninstall cleanly reverts.
5. The hook path never blocks or slows Claude Code, and never corrupts the user's `settings.json`.

---

## 2. Non-goals (v1) — deferred to v2+, enabled by this design

- **Act-in-place** (approve/deny permissions, answer AskUserQuestion, plan review from the notch). v2 flips `PermissionRequest`/`PreToolUse` hooks from fire-and-forget to synchronous decisions.
- **Usage/cost tracking** (ccusage recipe + CCSeva OAuth server-truth rate limits).
- **More agents** (Codex, Gemini CLI) — via the pluggable agent-adapter seam.
- **More terminals precisely** (Ghostty, Warp, tmux, VS Code) — via the `TerminalJumper` seam.
- **SSH remote** monitoring and **mobile** relay (Happy/Omnara pattern).

These are explicitly out of v1 scope but the architecture is designed so each is an additive change, not a rewrite.

---

## 3. Users & use case

- Single developer on an Apple-Silicon MacBook with a notch (floating-bar fallback on notchless/external displays).
- Runs Claude Code in **iTerm2**, arranged as **native split panes and native tabs** (no tmux in v1).
- Wants glanceable status + instant jump, without the app stealing focus from the terminal.

---

## 4. Prior art & key decisions

Grounded in real open-source implementations (read at source level):

- **State detection = Claude Code hooks** (not PTY-wrapping, not log-tailing). Proven by `nov1n/squawk`, `marshmansf/claude-code-menu-bar`, `slopus/happy-cli`. Hooks give a clean 1:1 event→state mapping and a reliable process↔session identity that log-tailing cannot. PTY-wrapping is version-brittle (Omnara abandoned it); JSONL log-tailing cannot signal "waiting for permission." **Accepted limitation:** hooks are read at session start, so we only observe sessions launched *after* install.
- **Transport = localhost HTTP server in the app + a tiny bundled helper.** HTTP-server pattern from marshmansf/Happy. The helper exists solely to capture `ITERM_SESSION_ID` (an env var absent from hook stdin) — our precise-jump key.
- **Notch UI = DynamicNotchKit** (MIT, macOS 13+): non-activating panel (`[.borderless, .nonactivatingPanel]` + `orderFrontRegardless()`, `.screenSaver` level) and notchless floating-bar fallback, out of the box.
- **Jump = iTerm2 AppleScript** matching the UUID suffix of `ITERM_SESSION_ID` (`select` window→tab→session + `activate`). Deliberately **no yabai** (unlike `farouqaldori/vibe-notch`), which would require partially disabling SIP.

---

## 5. Architecture overview

Three cooperating parts; only the app is long-running.

```
┌─ Claude Code session (per iTerm2 pane/tab) ─────────────┐
│  fires hooks ──► notch-bridge  (tiny bundled helper)     │
│                    • reads stdin JSON (session_id, cwd…) │
│                    • injects env (ITERM_SESSION_ID…)     │
│                    • reads bridge.json {port, token}     │
└───────────────────────────┬─────────────────────────────┘
                             │ HTTP POST 127.0.0.1:<port>/hook/<event>  (+ token header)
                             ▼
┌──────────────── ClaudeNotch.app  (Swift, .accessory) ───────────────┐
│  HookServer → SessionStore(state machine) → NotchController (UI)     │
│                         │                         │                  │
│                    SoundPlayer            TerminalJumper ──► iTerm2   │
│  HookInstaller (settings.json merge)                (AppleScript)    │
└──────────────────────────────────────────────────────────────────────┘
```

**Port/token decoupling:** `settings.json` stores only the static helper path. On launch the app picks a free port + random token and writes `~/Library/Application Support/ClaudeNotch/bridge.json` (mode `0600`). The helper reads it each invocation. The port can change without rewriting `settings.json`; the token prevents other local processes from spoofing events.

**Layering (top→bottom, no upward reach, no skipping):**
`AppCoordinator` (composition root / DI) → transport (`HookServer`) → domain (`SessionStore` state machine, pure) → presentation (`NotchController`) + side-effect adapters (`TerminalJumper`, `SoundPlayer`, `HookInstaller`).

---

## 6. Components & responsibilities

Each unit has one purpose, a defined interface, and is independently testable.

| Component | Purpose | Interface (sketch) | Depends on |
|---|---|---|---|
| **notch-bridge** (binary) | Capture event: stdin JSON + env → POST to app | `notch-bridge <event>` | bridge.json; URLSession (no curl/jq dependency) |
| **HookServer** | Receive events on localhost, auth by token | `var onEvent: (HookEvent) -> Void` | Network.framework |
| **HookEvent** | Parsed, validated event value type | decoded from POST body | — |
| **SessionStore** | Registry + **state machine**; publishes changes | `apply(HookEvent)`, `@Published sessions` | none (pure/testable) |
| **NotchController** | Render compact pill + expanded list; route clicks | `render([Session])`, `var onJump: (Session)->Void` | DynamicNotchKit |
| **TerminalJumper** *(protocol)* | Focus a session's pane | `func jump(to: Session) async -> JumpResult` | — |
| ├ `ITerm2Jumper` | Precise jump via AppleScript | conforms | iTerm2 (Apple Events) |
| └ `FallbackActivator` | Best-effort app raise | conforms | NSWorkspace |
| **TerminalJumperRegistry** | Select jumper by session's terminal | `jumper(for: Session) -> TerminalJumper` | the jumpers |
| **SoundPlayer** | Completion / failure sounds | `play(SoundEvent)` | AVFoundation |
| **HookInstaller** | Idempotent settings.json merge / uninstall / status | `install()`, `uninstall()`, `status()` | filesystem |
| **BridgeConfigWriter** | Write/refresh bridge.json {port, token} | `write(port:token:)` | filesystem |
| **AppCoordinator** | Composition root: wire, lifecycle, GC timer | — | all of the above |

`TerminalJumper` and a future `AgentAdapter` are the two deliberate extension seams: adding Ghostty/tmux jumpers or Codex/Gemini support is "implement the protocol + register," with no caller changes. v1 proves the seam by shipping two jumper conformances (iTerm2 + fallback) behind the registry.

---

## 7. Data model & state machine

```swift
struct Session: Identifiable {
    let key: String              // stable key = ITERM_SESSION_ID UUID suffix; fallback = claude session_id
    var claudeSessionID: String
    var terminal: TerminalRef    // .iterm(uuid: String) | .other(termProgram: String, pid: Int?)
    var cwd: String
    var title: String?           // session_title, else derived from cwd basename
    var model: String?
    var state: SessionState
    var currentTool: String?     // "Edit", "Bash"… for the working label
    var startedAt: Date
    var lastEventAt: Date
}

enum SessionState { case working, needsInput, needsPermission, done, failed, ended }
```

**Transition table** (driven purely by hook events — no terminal string parsing):

| Incoming event (matcher) | → State | Side effect |
|---|---|---|
| `SessionStart` | register → working | capture terminal coords |
| `PreToolUse` | working (+ tool) | — |
| `Notification` (`idle_prompt` \| `elicitation_dialog` \| `agent_needs_input`) | needsInput | — |
| `Notification` (`permission_prompt`) / `PermissionRequest` | needsPermission | — |
| `Stop` | done | play `done` sound |
| `StopFailure` | failed | play `failed` sound |
| `SessionEnd` | ended | remove after short grace period |

**Garbage collection:** a session with no event for `inactivityTimeout` (default 30 min, configurable) is dropped so the notch never shows ghosts from crashed/killed sessions.

---

## 8. Wire protocol & hook configuration

**Event POST body** (`POST /hook/<event>`), assembled by the helper:
```json
{
  "hook_event_name": "Notification",
  "session_id": "abc123",
  "transcript_path": "/…/abc123.jsonl",
  "cwd": "/Users/you/project",
  "matcher": "permission_prompt",
  "tool_name": "Bash",
  "env": { "ITERM_SESSION_ID": "w0t1p0:UUID", "TERM_PROGRAM": "iTerm.app", "PID": "12345" }
}
```
Request carries `X-ClaudeNotch-Token: <token>`; the server rejects mismatches with 401.

**Written into `~/.claude/settings.json`** — idempotent, marker-fenced, preserves existing user hooks, all `async` fire-and-forget for v1:
```jsonc
{ "hooks": {
  "SessionStart": [{ "matcher":"*", "hooks":[{ "type":"command", "command":"<APP>/Contents/Helpers/notch-bridge SessionStart", "async": true }] }],
  "PreToolUse":   [{ "matcher":"*", "hooks":[{ "type":"command", "command":"<APP>/…/notch-bridge PreToolUse",   "async": true }] }],
  "Notification": [{ "matcher":"*", "hooks":[{ "type":"command", "command":"<APP>/…/notch-bridge Notification", "async": true }] }],
  "Stop":         [{ "matcher":"*", "hooks":[{ "type":"command", "command":"<APP>/…/notch-bridge Stop",         "async": true }] }],
  "StopFailure":  [{ "matcher":"*", "hooks":[{ "type":"command", "command":"<APP>/…/notch-bridge StopFailure",  "async": true }] }],
  "SessionEnd":   [{ "matcher":"*", "hooks":[{ "type":"command", "command":"<APP>/…/notch-bridge SessionEnd",   "async": true }] }]
}}
```
- Our entries carry a marker (e.g. a sentinel comment field or a recognizable command path) so `uninstall()` removes exactly ours.
- `PermissionRequest` is registered only if the installed Claude Code version supports it (feature-detected); otherwise `Notification`'s `permission_prompt` matcher covers the needs-permission state.
- Writes are atomic (temp file + rename) with a timestamped backup of the prior `settings.json`.

---

## 9. Notch UX

- **Idle:** hidden (near-zero footprint), Dynamic-Island style.
- **Compact pill** (something needs attention): counts, e.g. `🟠2 🔵3` via `compactLeading`/`compactTrailing`.
- **Expanded** (on hover or on a state change worth surfacing): one row per session —
  ```
  🟠  api-service      needs permission · Bash      ↵ jump
  🟠  web-frontend     needs input                  ↵ jump
  🔵  worker-queue     working · Editing            ↵ jump
  ✅  billing-svc      done                         ↵ jump
  ```
  Clicking a row calls `TerminalJumper.jump`. The non-activating panel means hover/click never steals focus until the explicit jump.
- **Sound** on `Stop`/`StopFailure`; toggle + basic prefs in a minimal menu-bar item (install/uninstall hooks, sound on/off, quit).

Interaction defaults (confirm at build time; cheap to change): expanded on hover, auto-expand briefly on a new needs-permission/needs-input event, collapse on mouse-out.

---

## 10. Error handling & edge cases

| Case | Handling |
|---|---|
| Port in use | pick another free port; rewrite bridge.json |
| Automation (TCC) denied | jump falls back to app-activate; one-time explainer to grant Automation permission |
| iTerm session closed | AppleScript match fails → fallback activate iTerm; drop stale coords |
| `settings.json` missing / malformed / locked | create if absent; back up; atomic write; surface clear error; never corrupt |
| Helper can't reach app (not running) | POST fails silently; hooks are `async` so Claude Code is never blocked |
| Session never emits `Stop` (crash) | GC after `inactivityTimeout` |
| Non-iTerm terminal | `FallbackActivator` (app raise + best-effort) |
| Multiple displays / notchless | DynamicNotchKit floating-bar fallback; render on the built-in/notched screen explicitly |

**Guiding rule:** the hook path must never degrade Claude Code — every failure mode ends in a silent no-op.

---

## 11. Security & privacy

- HTTP server binds **127.0.0.1 only**; every request must carry the bridge token (else 401) — stops other local apps spoofing events.
- **No external network, no telemetry, no accounts.**
- v1 handles only metadata (session id, cwd, tool name, state); it does **not** read transcript content.
- `bridge.json` is `0600`; token is random per launch.
- Ship **unsandboxed** (Automation entitlements for iTerm control); `NSAppleEventsUsageDescription` in Info.plist.

---

## 12. Coding standards & extensibility

- **Contracts first:** `TerminalJumper` (and a future `AgentAdapter`) are protocols with a registry; new implementations register without touching callers.
- **Dependency injection:** `AppCoordinator` is the composition root; components receive collaborators via initializers (protocol types), enabling fakes in tests.
- **Pure domain core:** `SessionStore` (the state machine) has no I/O — all side effects live in adapters behind protocols.
- **Layered boundaries:** transport → domain → presentation/adapters; no upward or skip dependencies.
- **Small, focused units:** one responsibility per file/type; keep files small enough to reason about whole.
- **Value types + explicit contracts** for events/model; docstrings on public interfaces.

---

## 13. Testing strategy (test the seam; no speculative tests)

- **SessionStore:** unit-test the full event→state transition table + GC (highest value; pure).
- **TerminalJumper seam:** a `FakeJumper` proves routing/registry; `ITerm2Jumper` validated by a manual/integration check (needs a real iTerm2).
- **HookInstaller:** idempotent merge, marker-scoped uninstall, and "preserves pre-existing user hooks" against fixture `settings.json` files.
- **End-to-end smoke:** `curl` a synthetic event to the running server → assert the session's state flips.
- No new UI tests and no speculative cases unless explicitly requested.

---

## 14. Tech stack & project layout

- **Swift 6, macOS 14+ (Apple Silicon), unsandboxed, `LSUIElement`/`.accessory`.**
- **DynamicNotchKit** via SwiftPM. Notch content = SwiftUI; app shell = AppKit.
- Info.plist: `NSAppleEventsUsageDescription`.

```
claude-notch/
  Package.swift                       # SPM (app target + helper target + tests)
  Sources/
    ClaudeNotchApp/
      AppCoordinator.swift            # composition root, lifecycle, GC
      Transport/HookServer.swift
      Transport/HookEvent.swift
      Domain/Session.swift
      Domain/SessionStore.swift       # state machine (pure)
      UI/NotchController.swift
      UI/…SwiftUI views
      Terminal/TerminalJumper.swift   # protocol + registry
      Terminal/ITerm2Jumper.swift
      Terminal/FallbackActivator.swift
      Sound/SoundPlayer.swift
      Install/HookInstaller.swift
      Install/BridgeConfigWriter.swift
    notch-bridge/
      main.swift                      # tiny helper
  Tests/ClaudeNotchTests/
  docs/superpowers/specs/
```

---

## 15. Build sequence (high-level; details go to the implementation plan)

1. **Skeleton + seams:** SPM project, `Session`/`SessionState`, `SessionStore` state machine + unit tests, protocols (`TerminalJumper`) with `FakeJumper`.
2. **Transport:** `HookEvent`, `HookServer` (127.0.0.1 + token), `BridgeConfigWriter`; smoke via `curl`.
3. **Helper:** `notch-bridge` (stdin + env capture → POST); wire end-to-end (curl-equivalent from a fake hook).
4. **Self-config:** `HookInstaller` (merge/uninstall/status) with fixture tests.
5. **Notch UI:** DynamicNotchKit integration; compact + expanded; bind to `SessionStore`.
6. **Jump:** `ITerm2Jumper` (AppleScript) + `FallbackActivator` + registry; TCC handling.
7. **Sound + prefs:** `SoundPlayer`, menu-bar item.
8. **Hardening:** error/edge cases, GC, backup/atomic writes; manual multi-session test in iTerm2.

---

## 16. Open questions / risks

- **`PermissionRequest` availability** across Claude Code versions — mitigated by feature detection + `Notification/permission_prompt` fallback.
- **Hook event names/matchers** are the integration contract; if Claude Code changes them, state mapping needs updating (isolated to the transition table).
- **TCC Automation prompt** friction on first jump — needs a clear one-time explainer.
- **Distribution/signing** (helper is a second executable) — decide dev-signing vs. notarization when packaging; not needed for local dev runs.
