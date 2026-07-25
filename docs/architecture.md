# Architecture

NotchDeck is a native macOS app with a lightweight helper binary (`notch-bridge`) that acts as the event funnel from AI agent hooks into the app's local HTTP server.

## Components

```
┌─────────────────────────────────────────────────────────┐
│                      macOS App                          │
│  ┌──────────────┐    ┌───────────────┐  ┌───────────┐  │
│  │  SessionStore │◄───│  HTTP Server  │  │ NotchUI   │  │
│  │  (state mgr) │    │  :7779/hook   │  │ (notch)   │  │
│  └──────────────┘    └───────┬───────┘  └───────────┘  │
│         │ sessions           │ events         ▲         │
│         └────────────────────┴────────────────┘         │
└─────────────────────────────────────────────────────────┘
              ▲ HTTP POST /hook
              │
┌─────────────────────┐
│   notch-bridge      │  (tiny helper binary, bundled)
│   (stdin → HTTP)    │
└─────────────────────┘
              ▲ JSON on stdin
              │
┌─────────────────────┐
│  AI Agent Hooks     │  (Claude Code / Codex / etc.)
│  PreToolUse         │
│  PostToolUse        │
│  Stop / Notify      │
└─────────────────────┘
```

## How Events Flow

1. **Agent fires a hook** — Claude Code / Codex executes `notch-bridge` as a hook handler, passing event JSON on stdin.
2. **notch-bridge** reads the JSON, enriches it with terminal env vars (from its own environment), and POSTs to `localhost:7779/hook`.
3. **HTTP server** in the macOS app receives the event, routes it through the appropriate `AgentProvider` for decoding.
4. **SessionStore** updates the session state (`working`, `needsInput`, `needsPermission`, `done`, `failed`).
5. **NotchUI** (DynamicNotchKit) redraws the notch with the latest state within milliseconds.

## HTTP Hook Payload

```json
{
  "agent_id": "claude",
  "session_id": "abc-123",
  "hook_event_name": "PreToolUse",
  "tool_name": "Edit",
  "tool_input": { ... },
  "cwd": "/Users/you/myproject",
  "env": {
    "ITERM_SESSION_ID": "w0t0p0:UUID",
    "TERM_PROGRAM": "iTerm.app"
  }
}
```

## Key Protocols

| Protocol | Purpose |
|----------|---------|
| `AgentProvider` | One agent's full integration (hooks, decoding, pricing, tools) |
| `TerminalIdentifying` | Reads env vars → produces a `TerminalIdentity` |
| `TerminalJumping` | Takes a `TerminalIdentity` → focuses the right window/pane |
| `TranscriptParsing` | Reads agent transcript files → extracts token/cost usage |
| `HookEventMapping` | Maps raw hook JSON → `HookEvent` domain model |
