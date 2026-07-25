# ClaudeNotch — Multi-Agent Support (Pluggable `AgentProvider` Seam) — Design Spec

- **Status:** Approved (design). Ready for implementation planning.
- **Date:** 2026-07-23
- **Builds on:** v1 (shipped, `1e02512`), v2 act-in-place (shipped, `ed9a095`), rich glance (shipped, `95151d7`), interaction fixes (shipped, `8787331`), multi-terminal seam / Axis 1 (shipped, `0d4b6a3`). See sibling specs in `docs/superpowers/specs/`.
- **Repo policy:** Local git only. No remote, nothing pushed. No JIRA tracking for this project.
- **Scope decision:** This is **Axis 2 (more AI agents)**. The first non-Claude agent is **Codex CLI**, built to **full parity** (monitoring + jump + act-in-place + usage/cost). Gemini CLI is explicitly parked (see §3). Axis 1 (terminals) shipped separately and is unchanged here.

---

## 1. Purpose & goals

Today ClaudeNotch monitors only **Claude Code** sessions. The core (transport, session store, decision broker, terminal seam) is agent-agnostic, but **eleven edges are hardwired to Claude Code**: the install target/schema, the version gate, the hook event vocabulary, the inbound-payload field names, the tool→decision mapping, the outbound decision JSON, the installer↔bridge argv contract, the transcript schema, the pricing table, the tool-input renderer, and the one Claude-named field in the domain model. Adding a second agent today would mean editing every one of those in place.

This increment does two things:
1. **Refactors the eleven Claude-hardwired edges into a genuinely pluggable `AgentProvider` seam** so a *future* agent is added in a few additive edits with **no in-place surgery** to the shared machinery — the direct analog of the terminal seam shipped in Axis 1.
2. **Ships full Codex CLI support** as the first adapter proving the seam, alongside the existing Claude Code adapter.

**Success criteria:**
1. Adding any future agent requires only: one `AgentProvider` conformer (Core), its per-concern pieces (or inherited shared defaults), one registration line, and — if it installs hooks differently — one `AgentInstallProfile`. **No edits to the transport, `DecisionBroker`, `SessionStore` control flow, the terminal seam, or the bridge’s HTTP mechanics.**
2. Claude Code behavior is **byte-for-byte unchanged** from today (same hooks installed, same decode, same decision JSON, same usage/cost).
3. Codex sessions appear in the notch with correct glance states, jump precisely (via the existing terminal seam), support act-in-place tool allow/deny, and report usage/cost.
4. Events are attributed to the correct agent deterministically, and an unknown/missing agent id **degrades to the Claude provider** so pre-existing installs keep working.
5. Every per-agent concern is independently unit-testable with a **fake `AgentProvider`**, proving the seam without a live `codex` binary.

---

## 2. Scope & non-goals

**In scope:**
- A per-concern `AgentProvider` seam (pure, `ClaudeNotchCore`) resolved by an `AgentRegistry`, mirroring `TerminalIdentifierRegistry`.
- An `agentID` that travels on the wire: installer bakes `--agent <id>` into each hook’s bridge argv; the bridge injects `agent_id`; `HookEvent` carries it; the registry resolves the provider.
- Extracting today’s Claude logic onto a `ClaudeProvider` with **no behavior change**, and a `BaseAgentProvider` supplying shared defaults (the byte-identical decode + decision encoder).
- A full `CodexProvider`: install into `~/.codex/hooks.json`, event mapping, tool-permission act-in-place, Codex transcript parsing, OpenAI pricing, Codex tool rendering, presence detection, version gate.
- Focused seam tests (registry resolution; fake-provider round-trip; Codex encoder-equals-Claude; Codex render catalog) — see §12.

**Explicitly out of scope:**
- **Gemini CLI.** It has **no hook system** (only MCP, extensions, and OTLP telemetry), so it cannot drive the push/hook model this architecture is built on. Supporting it would need a separate poll/tail ingestion path — parked. The seam does not need to accommodate it now.
- **A TOML install writer.** Codex reads the same `{"hooks": {…}}` JSON shape from `~/.codex/hooks.json`, so no TOML is required. `AgentInstallProfile.format` reserves `.toml` for a future agent but only `.json` is implemented.
- **Product rename.** The app stays “ClaudeNotch”; the `X-ClaudeNotch-Token` header and `ClaudeNotch` Application Support folder are branding, not agent coupling, and are unchanged.
- **Codex `AskUserQuestion` / plan-approval answer-in-place.** Codex has no such tools; those decision kinds simply aren’t produced for Codex (graceful, not an error).
- Any change to the terminal seam, the loopback transport framing, the `DecisionBroker`, rich glance, or the UI beyond the `Session` field rename.

---

## 3. Users & use case

The same single developer running parallel AI-agent sessions on a notched Apple-Silicon MacBook — but no longer only Claude Code. They may run Claude Code and Codex CLI side by side (in any supported terminal). Each session shows its state in the notch, the row click-jumps to the exact pane (terminal seam, already agent-agnostic), and permission prompts can be answered in-place — regardless of which agent produced them, without the developer thinking about which agent is which.

---

## 4. Key decisions

- **Split by concern, not one fat protocol.** `AgentProvider` vends small, single-purpose pieces (`installProfile`, `eventMapper`, `decisionMapper`, `decisionEncoder`, `transcriptParser`, `costEstimator`, `toolRenderer`). This respects ISP, keeps each concern independently testable, and matches the codebase’s contracts-first ethos and the terminal seam’s precedent. Rejected: a single god-protocol (forces every agent to reimplement identical bits, mixes pure/impure) and a data-descriptor struct (degrades to closure/flag soup for the concerns that are real logic).
- **Shared defaults make the next agent cheap.** A `BaseAgentProvider` implements the byte-identical decode and the `hookSpecificOutput` decision encoder. `ClaudeProvider`/`CodexProvider` override only what genuinely differs. Because Codex’s hook contract is ~isomorphic to Claude’s, Codex reuses the base decoder and the base encoder verbatim.
- **Agent identity is explicit at install time, carried on the wire.** Unlike terminals (identified from env at runtime), we always know the agent when we install its hooks. The installer writes `notch-bridge --agent <id> <event> …`; the bridge injects `payload["agent_id"]`; `HookEvent.agentID` carries it; `AgentRegistry.provider(for:)` resolves it. Robust and requires no inference.
- **Unknown/missing agent id → Claude.** Guarantees pre-existing installs (which emit no `agent_id`) keep working byte-for-byte, and any future/unrecognized id fails safe onto the most-featured provider.
- **`TokenUsage` stays a four-bucket superset.** OpenAI billing has input/output/cached-input (no cache-write). Codex’s parser fills `cacheCreation = 0` and maps cached-input → `cacheRead`; `OpenAIPricing` ignores the cache-write rate. No change to the `TokenUsage` value type or its consumers.
- **Codex `model` comes free on every hook payload.** Codex includes `model` in hook stdin, so the session’s model can be set immediately from the event, independent of transcript parsing (which still supplies token counts).
- **Codex monitor hooks are synchronous.** Codex does not support `async` hooks (parsed but ignored). `AgentInstallProfile.supportsAsyncHooks = false` for Codex → monitor hooks install without `async` and with a short timeout; the bridge already POSTs-and-returns fast, so the hook completes well under the timeout and the CLI never stalls.

---

## 5. Architecture overview

The shared machinery is unchanged. Only the eleven edges move behind the provider, resolved per event by `agentID`.

```
Install (per present agent):
  for provider in AgentRegistry.presentProviders():
    HookInstaller.install(provider.installProfile)      // path + format + specs + async + versionGate
      Claude → ~/.claude/settings.json (JSON)
      Codex  → ~/.codex/hooks.json     (JSON, same {"hooks":{…}} shape)
    each hook command = "<helperPath>" --agent <id> <event> [subtype]

Ingest (env+agent → session), pure Core:
  agent hook → notch-bridge --agent <id> <event> [subtype]
    → injects payload["agent_id"] = id   (env allowlist + PID already handled by terminal seam)
    → POST /hook/<event> → HookServer (transport UNCHANGED)
    → provider = AgentRegistry.provider(for: payload.agent_id)   // missing/unknown → claude
    → event = provider.eventMapper.decode(payload, name:)         // shared default + per-agent bits
    → SessionStore.apply(event, provider):
         key    = SessionKey.derive(identity:, sessionID:)         // terminal seam, UNCHANGED
         labels = provider.toolRenderer.actionLabel(...)           // per-agent tool catalog
         Session.agentID = provider.agentID

Decide (act-in-place), pure Core:
  agent decide-hook → notch-bridge --agent <id> decide <event>
    → provider = registry.provider(for: agent_id)
    → request = provider.decisionMapper.request(from: event)       // tool → DecisionRequest
    → DecisionBroker.decide(request)                               // UNCHANGED
    → json = provider.decisionEncoder.stdout(for: decision)        // Claude & Codex share default
    → HookServer writes json back → bridge prints to stdout        // transport UNCHANGED

Usage/cost, pure Core:
  UsageTracker(for: agentID)
    → provider.transcriptParser.parse(chunk)  → (model, usageDelta)
    → provider.costEstimator.cost(model:tokens:)
```

**Layering (unchanged discipline):** all seams are pure and live in `ClaudeNotchCore` (decision-encode is pure JSON construction). Only install file-I/O (`HookInstaller`) and the version subprocess touch the OS; both are wired from `AppCoordinator` (App), exactly as today. `AppCoordinator` builds one shared `AgentRegistry`, installs each present provider, and injects the registry into `SessionStore`, `UsageTracker`, and the `HookServer` decode/decide path.

---

## 6. Components & responsibilities

| Component | New/Mod | Layer | Purpose | Interface (sketch) |
|---|---|---|---|---|
| **AgentProvider** | new | Core (seam) | vends one agent’s per-concern pieces | `agentID`, `displayName`, `isPresent()`, `installProfile`, `eventMapper`, `decisionMapper`, `decisionEncoder`, `transcriptParser`, `costEstimator`, `toolRenderer` |
| **BaseAgentProvider** | new | Core | shared defaults (byte-identical decode + encoder) | partial conformance others inherit |
| **AgentRegistry** | new | Core | resolve provider by id; list present agents | `provider(for:) -> AgentProvider` (unknown→claude), `presentProviders()`, `.default` |
| **AgentInstallProfile** | new | Core (data) | one agent’s install target + specs | `{ settingsURL, format, specs:[HookSpec], supportsAsyncHooks, versionGate? }` |
| **HookEventMapping** | new | Core (seam) | payload → `HookEvent` (field names, event vocab, matcher subtypes, optional `model`) | `decode(_ payload:name:now:) -> HookEvent` |
| **DecisionMapping** | new | Core (seam) | `HookEvent` → `DecisionRequest` (tool names) | `request(from:) -> DecisionRequest?` |
| **DecisionEncoding** | new | Core (seam) | `Decision` → hook stdout JSON | `stdout(for:) -> String?`, `answerStdout(...)` |
| **TranscriptParsing** | mod | Core (seam) | JSONL chunk → `(model, usageDelta)` | `parse(_:) -> TranscriptScan` (exists; now per-agent) |
| **ToolRendering** | new | Core (seam) | tool name+input → `ToolPreview` / action label | `render(...)`, `actionLabel(...)` |
| **ClaudeProvider** | new | Core | today’s Claude logic, extracted, unchanged behavior | conforms; overrides Claude specifics |
| **CodexProvider** | new | Core | Codex install/map/parse/price/render + detection | conforms; overrides Codex specifics |
| **ClaudePricing / OpenAIPricing** | mod/new | Core | per-agent `CostEstimator` impls | `cost(model:tokens:)` |
| **ClaudeTranscriptParser / CodexTranscriptParser** | mod/new | Core | per-agent JSONL schema | conforms `TranscriptParsing` |
| **ClaudeToolRenderer / CodexToolRenderer** | mod/new | Core | per-agent tool catalog | conforms `ToolRendering` |
| **HookEvent** | mod | Core | add `agentID: String` | value type |
| **Session** | mod | Core | `claudeSessionID` → `agentSessionID`; add `agentID` | value type |
| **SessionStore** | mod | Core | `apply(event, provider)`; labels via `provider.toolRenderer`; matcher/state mapping via `eventMapper` where it differs | inject registry |
| **HookServer** | mod | App | resolve provider by `agent_id`; use it for decode + decide encode | transport framing unchanged |
| **HookInstaller** | mod | Core | install from an `AgentInstallProfile` (path/format/specs/async) instead of hardcoded Claude specs | `install(_ profile:)` |
| **notch-bridge/main** | mod | bridge | parse `--agent <id>`; inject `payload["agent_id"]` | — |
| **AppCoordinator** | mod | root | build `AgentRegistry`; install each present provider; per-agent version gate; inject registry | — |

`HookEventMapping`, `DecisionMapping`, `DecisionEncoding`, `TranscriptParsing`, `ToolRendering`, `CostEstimator`, and `AgentRegistry` are the pure/seam test targets (see §12).

---

## 7. Agent routing & identity resolution

- **On the wire:** the installer writes each hook’s command as `"<helperPath>" --agent <id> <event> [subtype]` (extending today’s positional `args` contract shared between `HookInstaller.Spec.args` and `notch-bridge/main.swift`). The bridge parses the leading `--agent <id>` and sets `payload["agent_id"] = id` before POSTing. Env-allowlist forwarding and PID injection are untouched (still driven by the terminal `TerminalIdentifierRegistry.allEnvKeys`).
- **In the app:** `HookEvent` gains `agentID: String`. `HookServer` reads `agent_id` from the decoded payload (before full decode) and calls `AgentRegistry.provider(for: agentID)`; a missing or unrecognized id resolves to the **Claude provider** (back-compat + fail-safe). The resolved provider drives decode, decision mapping/encoding, and (via `SessionStore`) rendering.
- **Session identity/keying is unchanged.** `SessionKey.derive(identity:sessionID:)` still prefers the terminal handle, else the agent session id. Agents don’t change keying; two agents in the same pane are distinguished by their differing session ids when no terminal handle exists. `Session.claudeSessionID` is renamed `agentSessionID` (semantics identical) and `Session.agentID` is added for display/grouping.

---

## 8. Decision / act-in-place path

- **Mapping (`DecisionMapping`):** Claude maps `AskUserQuestion` → `.question`, `ExitPlanMode` → `.planApproval`, else `.toolPermission` (today’s `DecisionRequest.from`). Codex maps everything to `.toolPermission` (it has no question/plan tools). The `Decision`, `DecisionKind`, `DecisionRequest`, `QuestionSpec`, and the entire `DecisionBroker` are **unchanged and shared**.
- **Encoding (`DecisionEncoding`):** the `hookSpecificOutput` envelope is **identical between Claude and Codex** — verified: `PermissionRequest` → `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"|"deny","message"?}}}`; `PreToolUse` → `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"|"deny","permissionDecisionReason"?,"updatedInput"?}}`. Both providers inherit the shared `BaseAgentProvider` encoder. `.passthrough`/timeout → emit nothing (both agents show their own dialog). Codex `answer`-in-place is N/A (no `AskUserQuestion`).
- **Codex nuances:** Codex resolves multiple hooks as “any deny wins,” which matches our single-decision model. `"ask"`, legacy `"approve"`, and `continue:false` are “parsed but not supported” by Codex — we never emit them, so no conflict.

---

## 9. Usage / cost & transcript

- **Path source:** both agents deliver `transcript_path` in the hook payload (Claude → `~/.claude/projects/.../<session>.jsonl`; Codex → its rollout/`history.jsonl`). `TranscriptReader` is already a generic “tail a JSONL file” reader and is unchanged; only the **parser** is per-agent.
- **Parsing (`TranscriptParsing`):** Claude parser reads `type=="assistant"` → `message.model` + `message.usage.{input_tokens,output_tokens,cache_creation_input_tokens,cache_read_input_tokens}` (today’s `TranscriptParser`). Codex parser reads Codex’s rollout schema for per-turn model + token buckets. **Exact Codex usage keys are verified at plan time (open item #1).**
- **Pricing (`CostEstimator`):** `CostEstimator` is already a protocol. `ClaudePricing` = today’s `BundledPricing` (Anthropic ids + rates + prefix match). `OpenAIPricing` = Codex model ids + OpenAI rates, mapping cached-input → `cacheRead`. `UsageTracker` becomes agent-aware: keyed by transcript path as today, but it uses the provider’s parser + estimator for that session’s `agentID`.

---

## 10. Codex adapter specifics

- **Install:** `~/.codex/hooks.json`, `format = .json`, **reusing the existing JSON hook-writer** (same `{"hooks":{ Event: [ { matcher, hooks:[ {type:"command", command, timeout} ] } ] }}` shape). `supportsAsyncHooks = false` → monitor hooks omit `async` and use a short timeout; decide hooks are synchronous with a 600s timeout (Codex default). Presence detection: `codex` on `PATH` or `~/.codex` exists.
- **Version gate:** `codex --version`; minimum version that supports hooks + the `--version` string format are **verified at plan time (open item #2)**. If undetectable, degrade to monitor-only for Codex (no decide hooks installed), never crash.
- **Events:** same `HookEventName` values; Codex uses `PermissionRequest` directly (no `Notification permission_prompt`/`needs_input` matcher split — those matcher literals stay Claude-only in `SessionStore`/`eventMapper`). Codex `model` from stdin sets the session model immediately.
- **Act-in-place:** `.toolPermission` allow/deny on `Bash` / `apply_patch` (and MCP tools); shared encoder.
- **Tool render (`CodexToolRenderer`):** `Bash` → `.command` (from `tool_input.command`), `apply_patch` → `.diff`, default → `.raw` / tool name. Reuses the existing `ToolPreview` taxonomy.
- **Pricing:** `OpenAIPricing` table (values verified at plan time, open item #3).

---

## 11. Error handling & edge cases

| Case | Handling |
|---|---|
| Missing/empty `agent_id` (old installs) | resolve to Claude provider → byte-for-byte legacy behavior |
| Unknown `agent_id` | resolve to Claude provider (fail-safe) |
| Codex not installed | `isPresent()` false → no Codex hooks installed; Claude unaffected |
| Codex version too old / undetectable | install monitor hooks only (skip decide); never crash |
| Codex transcript schema unrecognized | parser returns zero delta → cost nil (monitor still works), like an unknown Claude model |
| Codex `async` ignored | monitor hooks installed sync + short timeout; bridge returns fast → no CLI stall |
| Codex tool not in catalog | `.raw` render / bare tool name (same degrade as Claude’s `default`) |
| Two agents in the same pane, no terminal handle | keyed by their distinct session ids (unchanged keying) |
| Decision timeout / passthrough | emit nothing → agent shows its own dialog (both agents) |

---

## 12. Security & privacy

- **No new network surface, no telemetry, no new disk writes** beyond installing hooks into the agent’s own config file (with a backup, as today). Identity/session/decision state stays in-memory.
- **Env forwarding is unchanged** and still a curated allowlist (terminal seam); no additional agent env vars are forwarded. `agent_id` is a fixed literal set by the installer, not user/free-text data.
- **Decision JSON is constructed from typed values**, not string-interpolated from untrusted input (unchanged). The loopback token (`X-ClaudeNotch-Token`) and port discovery are unchanged.
- Installing into `~/.codex/hooks.json` follows the same idempotent read-merge-write-with-backup discipline as `~/.claude/settings.json`; ownership is detected by the quoted `helperPath` prefix (unchanged mechanism), and `--agent <id>` in the command lets multiple agents’ hooks coexist unambiguously even within one file.

---

## 13. Build sequence (high-level; details go to the implementation plan)

1. **Seam protocols (Core):** define `AgentProvider`, `AgentInstallProfile`, `HookEventMapping`, `DecisionMapping`, `DecisionEncoding`, `ToolRendering`; make `TranscriptParsing` a named protocol; add `BaseAgentProvider` shared defaults.
2. **Registry (Core):** `AgentRegistry` (`provider(for:)` with Claude fallback, `presentProviders()`, `.default`).
3. **Extract Claude (Core):** move today’s decode / `DecisionRequest.from` / `DecisionEncoder` / `TranscriptParser` / `BundledPricing` / `ToolInputRenderer` / install specs behind `ClaudeProvider` + shared defaults, with **zero behavior change** (existing tests stay green).
4. **Wire routing:** add `HookEvent.agentID`; `notch-bridge` `--agent` parse + `agent_id` injection; `HookServer` resolves provider; `SessionStore.apply(event, provider)`; rename `Session.claudeSessionID` → `agentSessionID` + add `agentID`.
5. **Generalize install:** `HookInstaller.install(_ profile:)`; `AppCoordinator` installs each `presentProviders()`; per-agent version gate.
6. **Codex adapter:** `CodexProvider` (install profile → `~/.codex/hooks.json`; event mapper; decision mapper; Codex transcript parser; `OpenAIPricing`; `CodexToolRenderer`; presence + version detection).
7. **Tests:** update existing tests to provider-parameterized signatures; add the focused seam tests below.
8. **Manual verification:** real runs of Claude (regression) and Codex — glance states, jump, act-in-place allow/deny, usage/cost — plus old-install (no `agent_id`) back-compat.

**Testing strategy (test-the-seam):** registry resolution (id→provider; unknown/missing→Claude); a **fake `AgentProvider`** round-tripping decode → decision map → encode → render → parse to prove the seam without a live binary; Codex decision-encoder output **equals** Claude’s for the same `Decision`; Codex tool-render catalog (`Bash`/`apply_patch`/default); Claude regression tests unchanged. No live `codex`/`claude` subprocess tests (covered by manual e2e, per the WezTerm/Kitty precedent).

---

## 14. Extension recipe (the deliverable, restated)

To add a future agent `Foo`:
1. **Core:** add `FooProvider: AgentProvider` — set `agentID:"foo"`, `isPresent()`, an `AgentInstallProfile` (its settings path/format/specs), and override only the per-concern pieces that differ from `BaseAgentProvider` (often just `transcriptParser`, `costEstimator`, `toolRenderer`, and a matcher tweak). Register in `AgentRegistry.default`.
2. **Wiring:** none — `AppCoordinator` already installs every present provider and routes by `agent_id`.

No edits to the transport, `DecisionBroker`, `SessionStore` control flow, the terminal seam, `HookInstaller`’s JSON writer, or the bridge’s mechanics. If the agent’s hook contract matches the `hookSpecificOutput` shape (as Claude and Codex do), it inherits decode and decision-encode for free.

---

## 15. Open questions / risks

- **Open item #1 — Codex transcript usage schema.** The exact per-session rollout/`history.jsonl` line keys for model + token buckets are not in the public config docs; confirm against the Codex OSS repo / a real rollout during implementation. Isolated behind `TranscriptParsing`; low architectural risk (worst case: cost nil, monitoring still works).
- **Open item #2 — Codex hooks minimum version + `codex --version` format.** Needed for the version gate; if undetectable, degrade to monitor-only. Confirm at plan/impl time.
- **Open item #3 — OpenAI price table values.** Fill `OpenAIPricing` with current Codex-model rates at implementation time; unknown model → nil cost (same contract as Claude).
- **Codex `apply_patch` diff rendering.** Codex’s patch payload shape may differ from Claude’s `Edit`/`MultiEdit`; the `CodexToolRenderer` maps it to the existing `.diff`/`.command`/`.raw` taxonomy, falling back to `.raw` if the shape is unexpected.
- **Coexistence in one config file / multiple agents.** `--agent <id>` in the command string plus the `helperPath` ownership prefix keep hooks unambiguous; verify idempotent install/uninstall for Codex mirrors Claude’s.
