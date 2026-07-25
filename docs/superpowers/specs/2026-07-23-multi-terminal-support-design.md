# ClaudeNotch — Multi-Terminal Support (Pluggable Terminal Seam) — Design Spec

- **Status:** Approved (design). Ready for implementation planning.
- **Date:** 2026-07-23
- **Builds on:** v1 (shipped, `1e02512`), v2 act-in-place (shipped, `ed9a095`), rich glance (shipped, `95151d7`), interaction fixes (shipped, `8787331`). See the sibling specs in `docs/superpowers/specs/`.
- **Repo policy:** Local git only. No remote, nothing pushed. No JIRA tracking for this project.
- **Scope decision:** This is **Axis 1 only** (terminals). Axis 2 (more AI agents like Codex) is explicitly parked; see the earlier architecture review, not covered here.

---

## 1. Purpose & goals

Today ClaudeNotch can precisely jump to a session only in **iTerm2**; every other terminal degrades to a best-effort app-raise. Terminal handling is also structurally closed: `TerminalRef` is a two-case enum and `TerminalJumperRegistry` hardcodes `iterm` + `fallback`, so adding a terminal means editing the enum and every exhaustive `switch` over it. The existing code even carries a comment promising "new terminals register here in v2 without touching callers" — this project makes that true.

This increment does two things:
1. **Refactors terminal handling into a genuinely pluggable seam** so a *future* terminal is added in a few additive edits with **zero switch surgery**.
2. **Ships precise jump for WezTerm and Kitty** as the first two adapters proving the seam, alongside the existing iTerm2 adapter and the generic fallback.

**Success criteria:**
1. Adding any future terminal requires only: one `TerminalIdentifying` type (Core), one `TerminalJumping` type (App), and one registration line each — **no edits to `switch` statements, `Session`, the bridge, decode, or keying logic.**
2. WezTerm and Kitty sessions jump precisely to the correct pane/window when their control CLI is available.
3. When precise targeting is unavailable (CLI missing, Kitty remote control disabled, `$TMUX` present, unknown terminal), the jump **silently degrades** to app-raise, and only a hard failure (no app at all) surfaces a notice — identical UX to today.
4. Session **identity and keying always resolve from env vars** and never depend on whether a terminal's jump CLI is reachable, so grouping/dedup/remembered-approvals behavior is preserved.
5. iTerm2 and generic-terminal behavior is **byte-for-byte unchanged** from today.

---

## 2. Scope & non-goals

**In scope:**
- A two-concern pluggable seam: **identity** (pure, `ClaudeNotchCore`) and **jumping** (impure, `ClaudeNotchApp`), linked by a string `adapterID`.
- Two real registries: `TerminalIdentifierRegistry` (priority-ordered, generic catch-all) and `TerminalJumperRegistry` (id→jumper + fallback, owning the degrade chain).
- Replacing the closed `TerminalRef` enum with a generic `TerminalIdentity` value.
- Making `HookEnv` a generic env bag and the `notch-bridge` env allowlist **data-driven** off the identifier registry.
- New precise adapters: **WezTerm** (`wezterm cli activate-pane`) and **Kitty** (`kitty @ focus-window`).
- Focused seam tests (identifier priority resolution; registry degrade-chain with fakes) — see §10.

**Explicitly out of scope:**
- **Axis 2 — more AI agents** (Codex, Gemini CLI). Parked.
- **tmux / multiplexer nesting.** If `$TMUX` is present we app-raise the outer terminal (fallback). tmux can be its own adapter later via this same seam.
- **Terminal.app and Ghostty precise adapters.** They ride the generic fallback for now; adding them later is exactly the extension recipe this spec enables (Terminal.app = tab-level AppleScript; Ghostty = fallback until it exposes a stable handle).
- **A one-time "enable remote control" hint** for Kitty. Nice-to-have; not built. Silent degrade only.
- Any change to the monitoring hook contract, the decision/act-in-place path, rich glance, or the UI beyond what the identity-type rename requires.

---

## 3. Users & use case

The same single developer running parallel Claude Code sessions on a notched Apple-Silicon MacBook — but no longer only in iTerm2. They may run sessions in WezTerm or Kitty (and occasionally Terminal.app, Ghostty, or others). Clicking a notch row should focus the exact pane/window where that terminal can do it, and gracefully raise the app where it can't — without the developer thinking about which terminal they're in.

---

## 4. Key decisions

- **Split identity from jumping.** Identity is pure and env-derived → lives in `ClaudeNotchCore`, unit-testable without AppKit. Jumping is OS-specific (AppleScript / subprocess / `NSWorkspace`) → lives in `ClaudeNotchApp`. The only coupling is the `adapterID` string. This is what keeps the core testable and the OS mechanics isolated.
- **Two real registries, not switches.** `TerminalIdentifierRegistry` resolves *which* terminal; `TerminalJumperRegistry` resolves *how* to jump and owns the fallback chain. Adding a terminal appends to a list; it never edits control flow.
- **Identity always resolves; jumping may degrade.** Env vars like `$WEZTERM_PANE` / `$KITTY_WINDOW_ID` are present regardless of whether the terminal's control CLI/remote-control is enabled. So keying/grouping is robust even when precise jump isn't possible. Identity and jump feasibility are independent axes.
- **Data-driven env allowlist.** The bridge forwards only the union of `requiredEnvKeys` declared by identifiers — curated, not "forward all env" (env routinely holds secrets; no reason to ship them over loopback). Adding a terminal that needs a new var updates one declaration; the bridge picks it up with no bridge edit.
- **Preserve keying semantics exactly.** Generalize the current rule to *stable handle when present, else Claude `session_id`*. For iTerm the handle is the UUID (unchanged); for generic terminals the handle is nil → `session_id` (unchanged); WezTerm/Kitty extend it naturally with their pane/window id.
- **CLI-based jumps avoid the TCC prompt.** WezTerm/Kitty jump via their own CLIs run as subprocesses, which (unlike iTerm2's `NSAppleScript`) does **not** trigger the macOS Automation permission dialog — those adapters work without the user granting Automation access.

---

## 5. Architecture overview

Monitoring and decision flows are unchanged. Only terminal identity resolution and the jump path are reshaped.

```
Ingest (env → identity), pure, Core:
  notch-bridge forwards allowlisted env (= registry.allEnvKeys)
    → POST /hook/<event> → HookServer → HookEvent.decode (generic env bag)
    → SessionStore.apply(event):
         identity = TerminalIdentifierRegistry.resolve(event.env)   // first match by priority, else generic
         key      = handle(identity) ?? session_id
         Session.terminal = identity

Jump (identity → focus), impure, App:
  NotchController click → AppCoordinator.onJump(session)
    → TerminalJumperRegistry.jump(to: session.terminal):
         jumper = jumpers[identity.adapterID]           // ITerm2 | WezTerm | Kitty
         r = await jumper?.jump(to: identity)
         switch r:
           .jumped   → done
           .fellBack → app already raised by adapter (e.g. iTerm activate) → return
           .failed / nil → await FallbackActivator.jump(identity)   // app-raise
    → .failed (no app at all) → error sound + notice   (unchanged UX)
```

**Layering (unchanged discipline):** `AppCoordinator` (root) wires a single shared `TerminalIdentifierRegistry` into `SessionStore` and constructs the `TerminalJumperRegistry`. Core stays AppKit-free; all OS-specific jump mechanics live in App adapters.

---

## 6. Components & responsibilities

| Component | New/Mod | Layer | Purpose | Interface (sketch) |
|---|---|---|---|---|
| **TerminalIdentity** | new | Core (pure) | generic terminal identity value; replaces `TerminalRef` enum | `{ adapterID:String, handle:String?, appName:String?, pid:Int? }` |
| **TerminalIdentifying** | new | Core (seam) | one terminal's env→identity rule | `adapterID`, `priority:Int`, `requiredEnvKeys:[String]`, `identify(_ env:HookEnv) -> TerminalIdentity?` |
| **TerminalIdentifierRegistry** | new | Core | pick identity by priority; expose env allowlist | `resolve(_ env:) -> TerminalIdentity`, `allEnvKeys:[String]`, `.default` |
| **ITerm2Identifier** | new | Core (pure) | `ITERM_SESSION_ID` → uuid handle (colon-split moves here) | conforms |
| **WezTermIdentifier** | new | Core (pure) | `WEZTERM_PANE` → pane-id handle | conforms |
| **KittyIdentifier** | new | Core (pure) | `KITTY_WINDOW_ID` → window-id handle | conforms |
| **GenericTerminalIdentifier** | new | Core (pure) | always matches (lowest priority); `appName` from `TERM_PROGRAM` | conforms |
| **HookEnv** | mod | Core (pure) | generic env bag + convenience accessors | `values:[String:String]`, `pid:Int?`, `var termProgram:String?` … |
| **HookEvent.decode** | mod | Core (pure) | copy whole `env` object into `values`; parse PID; no per-terminal fields | — |
| **Session** | mod | Core (pure) | `terminal:TerminalIdentity`; `projectName` uses `identity.appName` | value type |
| **SessionKey** | mod | Core (pure) | `derive(identity:sessionID:)` = handle ?? sessionID | — |
| **SessionStore** | mod | Core (pure) | inject `TerminalIdentifierRegistry`; resolve identity once in `apply` | ctor takes registry (default `.default`) |
| **TerminalJumping** | mod | App (seam) | one terminal's jump mechanic | `adapterID`, `jump(to identity:) async -> JumpResult` |
| **TerminalJumperRegistry** | mod | App | id→jumper + fallback; owns degrade chain | `jump(to identity:) async -> JumpResult` |
| **ITerm2Jumper** | mod | App | AppleScript tree-walk; reads `identity.handle` | conforms |
| **WezTermJumper** | new | App | `wezterm cli activate-pane --pane-id <handle>` subprocess | conforms |
| **KittyJumper** | new | App | `kitty @ focus-window --match id:<handle>` subprocess | conforms |
| **FallbackActivator** | mod | App | app-raise via `identity.appName`/`pid` | conforms |
| **notch-bridge/main** | mod | bridge | forward `TerminalIdentifierRegistry.default.allEnvKeys` | — |
| **AppCoordinator** | mod | root | share one identifier registry; build jumper registry; call `registry.jump(to:)` | — |

`TerminalIdentifying` implementations and both registries are the natural pure/seam test targets (see §10).

---

## 7. Data model

```swift
// Core, replaces the closed TerminalRef enum.
public struct TerminalIdentity: Sendable, Equatable {
    public let adapterID: String   // "iterm2" | "wezterm" | "kitty" | "generic"
    public let handle: String?     // stable per-pane/window id for precise jump; nil = no handle
    public let appName: String?    // e.g. "iTerm.app" / "WezTerm" — for app-raise + display
    public let pid: Int?
}

// Core, generic env bag (replaces typed itermSessionID/termProgram fields).
public struct HookEnv: Sendable, Equatable {
    public var values: [String: String]
    public var pid: Int?
    public var termProgram: String? { values["TERM_PROGRAM"] }   // convenience accessors kept
}

// Core seam.
public protocol TerminalIdentifying: Sendable {
    var adapterID: String { get }
    var priority: Int { get }              // higher wins; generic is lowest
    var requiredEnvKeys: [String] { get }  // union → bridge allowlist
    func identify(_ env: HookEnv) -> TerminalIdentity?   // nil = not mine
}
```

`Session.terminal` becomes `TerminalIdentity`. `Session.projectName` unchanged except the terminal-name fallback reads `identity.appName`. `JumpResult` (`.jumped` / `.fellBack` / `.failed`) is unchanged.

---

## 8. Identity resolution & keying

**Resolution (`TerminalIdentifierRegistry.resolve`):** iterate identifiers by descending `priority`; return the first non-nil `identify(env)`. `GenericTerminalIdentifier` matches unconditionally at lowest priority, so `resolve` is total (always returns an identity). Priority order: `iterm2` / `wezterm` / `kitty` (specific) above `generic`. Identifiers key off their own distinctive env var (`ITERM_SESSION_ID`, `WEZTERM_PANE`, `KITTY_WINDOW_ID`) — not `TERM_PROGRAM` — so overlaps don't occur in practice; priority is the deterministic tiebreak if they ever do.

**Keying (`SessionKey.derive(identity:sessionID:)`):** `identity.handle ?? sessionID`. This is the exact generalization of today's iTerm-UUID-first / session-id-else rule. Because handles come from env (always available), keying is independent of jump feasibility.

**`allEnvKeys`:** the de-duplicated union of every identifier's `requiredEnvKeys` (e.g. `["ITERM_SESSION_ID","WEZTERM_PANE","KITTY_WINDOW_ID","TERM_PROGRAM"]`). `notch-bridge` reads this to decide which env vars to forward.

---

## 9. Jumping & degrade chain

**Adapter contract (`TerminalJumping`):** attempt **precise targeting only**.
- `ITerm2Jumper` — unchanged AppleScript walk; `activate` raises the app, so a no-match returns `.fellBack`, an error returns `.failed`.
- `WezTermJumper` — `wezterm cli activate-pane --pane-id <handle>`; success `.jumped`, CLI missing / non-zero exit `.failed`.
- `KittyJumper` — `kitty @ focus-window --match id:<handle>`; success `.jumped`, remote-control disabled / CLI missing / non-zero exit `.failed`.

**Registry chain (`TerminalJumperRegistry.jump(to identity:)`):**
1. `jumper = jumpers[identity.adapterID]`; if none → go to step 4.
2. `r = await jumper.jump(to: identity)`.
3. `.jumped` → return `.jumped`; `.fellBack` → return `.fellBack` (adapter already raised the app); `.failed` → fall through.
4. `r2 = await fallback.jump(to: identity)` (app-raise via `appName`/`pid`); return `.fellBack` on raise, else `.failed`.

This centralizes fallback so adapters stay single-purpose, and reuses one app-raise implementation for every terminal.

**Subprocess execution:** run off the main thread with a short timeout (e.g. ~2s) and discard stdout; a timeout is treated as `.failed` → fallback. The UI never blocks on a jump.

---

## 10. Testing strategy

Existing tests are **updated** to the new signatures (required to keep the suite green): `TerminalJumperRegistryTests` (new `jump(to:)` chaining API + `TerminalIdentity`), `SessionStoreTests` (inject a fake/`default` identifier registry; `Session.terminal` is now `TerminalIdentity`), `HookEventTests` (generic `HookEnv`/decode), `DecisionTests`/others that construct `HookEnv` or reference `TerminalRef`.

New **focused seam tests** (approved, per the project's "test the seam" principle):
- **Identifier resolution:** each identifier returns the right `adapterID`/`handle` for a representative env and `nil` when its key is absent; `resolve` picks specific over generic by priority; `resolve` is total (generic catches unknown); `allEnvKeys` is the correct union.
- **Registry degrade-chain:** with fake `TerminalJumping` doubles — adapter `.jumped` short-circuits (fallback not called); adapter `.failed` invokes fallback; adapter `.fellBack` returns without fallback; missing adapter goes straight to fallback.
- **Keying:** `SessionKey.derive` returns handle when present, else `sessionID`.

No end-to-end subprocess tests for `wezterm`/`kitty` (they shell out to external binaries) — those are covered by manual verification (§13).

---

## 11. Error handling & edge cases

| Case | Handling |
|---|---|
| WezTerm/Kitty CLI not on PATH | subprocess spawn fails → `.failed` → registry app-raises |
| Kitty remote control disabled | `kitty @` non-zero exit → `.failed` → registry app-raises |
| Subprocess hangs | short timeout → `.failed` → registry app-raises; UI never blocks |
| `$TMUX` present (out of scope) | identifier still resolves the outer terminal for keying; jump degrades to app-raise |
| Unknown terminal | `GenericTerminalIdentifier` matches → app-raise via `TERM_PROGRAM` name |
| No app found at all | `.failed` → error sound + notice (unchanged UX) |
| Env var missing for an identifier | `identify` returns nil; a lower-priority identifier (ultimately generic) matches |
| Handle absent | keying falls back to `session_id`; jump degrades to app-raise |

---

## 12. Security & privacy

- **Curated env allowlist** in the bridge (union of `requiredEnvKeys`) — we do **not** forward arbitrary environment variables (which routinely contain API keys/secrets) over the loopback socket. Only the handful of terminal-identifying vars are sent.
- Subprocess jumpers invoke fixed binaries (`wezterm`, `kitty`) with the pane/window handle as an argument; the handle originates from the terminal's own env var. No shell string interpolation of untrusted free text into a shell — arguments are passed as an argv array (no `sh -c`).
- No new network, no telemetry, no disk writes. Identity/keying state remains in-memory (unchanged).
- iTerm2 path still uses AppleScript under the existing Automation entitlement; WezTerm/Kitty need no additional macOS permission.

---

## 13. Build sequence (high-level; details go to the implementation plan)

1. **Core value + generic env:** add `TerminalIdentity`; convert `HookEnv` to a generic bag + accessors; update `HookEvent.decode`; remove `TerminalRef` (fold iTerm colon-split into `ITerm2Identifier`).
2. **Identity seam:** `TerminalIdentifying` protocol; `ITerm2Identifier`, `WezTermIdentifier`, `KittyIdentifier`, `GenericTerminalIdentifier`; `TerminalIdentifierRegistry` (+ `.default`, `resolve`, `allEnvKeys`).
3. **Keying + store:** `SessionKey.derive(identity:sessionID:)`; inject the registry into `SessionStore`; resolve identity once in `apply` for both key and `Session.terminal`; update `Session.projectName`.
4. **Jump seam:** `TerminalJumping.jump(to identity:)`; `TerminalJumperRegistry.jump(to:)` degrade chain; update `ITerm2Jumper` + `FallbackActivator`; add `WezTermJumper`, `KittyJumper`.
5. **Bridge:** forward `TerminalIdentifierRegistry.default.allEnvKeys` instead of the three hardcoded vars.
6. **Wiring:** `AppCoordinator` shares one identifier registry with `SessionStore`, builds the jumper registry, and calls `registry.jump(to: session.terminal)` in `onJump`/`onAnswerInTerminal`.
7. **Tests:** update existing tests to new signatures; add the focused seam tests (§10).
8. **Manual verification:** real runs in iTerm2 (regression), WezTerm, Kitty (precise jump), and Terminal.app/an unknown terminal (fallback). Confirm keying/grouping and that failures surface correctly.

---

## 14. Extension recipe (the deliverable, restated)

To add a future terminal `Foo`:
1. **Core:** add `FooIdentifier: TerminalIdentifying` (`adapterID: "foo"`, `priority`, `requiredEnvKeys: ["FOO_PANE"]`, `identify`). Register in `TerminalIdentifierRegistry.default`.
2. **App:** add `FooJumper: TerminalJumping` (`adapterID: "foo"`, `jump(to:)`). Register in the `TerminalJumperRegistry` construction.

No edits to `switch` statements, `Session`, `HookEvent.decode`, `SessionKey`, the bridge, or any caller. The env allowlist and keying pick up the new terminal automatically. Terminal.app (tab-level AppleScript) and Ghostty are the obvious next candidates via this exact recipe.

---

## 15. Open questions / risks

- **WezTerm pane focus semantics** — `wezterm cli activate-pane` targets the pane; confirm it also brings the containing GUI window forward on macOS (if not, the adapter follows precise targeting with an `NSWorkspace` app-raise, still returning `.jumped`). Verify during implementation.
- **Kitty remote control friction** — precise jump requires `allow_remote_control` + a reachable socket; when absent we silently degrade. A future one-time setup hint is deliberately out of scope.
- **CLI discovery** — `wezterm`/`kitty` may not be on the app's `PATH` (GUI apps get a minimal PATH). The adapters should resolve the binary robustly (e.g. known install locations) before treating absence as `.failed`; detail this in the plan.
- **Handle stability** — assumes `$WEZTERM_PANE` / `$KITTY_WINDOW_ID` are stable for a session's lifetime (they are, per each terminal's model). If a session migrates panes, keying follows the original handle — acceptable and matches iTerm behavior today.
