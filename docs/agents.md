# Supported Agents

NotchDeck uses a plugin-style `AgentProvider` protocol — each agent is a self-contained adapter that handles hook installation, event decoding, decision encoding, transcript parsing, cost estimation, and tool rendering.

## Currently Supported

### 🤖 Claude Code (Anthropic)
- **Agent ID:** `claude`
- **Hook type:** Claude Code hooks (`PreToolUse`, `PostToolUse`, `Stop`, `Notification`)
- **Features:** Session state, tool previews, cost tracking (input/output/cache tokens), permission decisions
- **Auto-install:** Yes — NotchDeck writes hooks to `~/.claude/settings.json` on first launch

### 🤖 Codex CLI (OpenAI)
- **Agent ID:** `codex`
- **Hook type:** Codex exec hooks
- **Features:** Session state, tool previews, cost tracking (OpenAI pricing), transcript parsing
- **Auto-install:** Yes — NotchDeck configures Codex hooks automatically

## Planned

| Agent | Status |
|-------|--------|
| Gemini CLI (Google) | Planned |
| Aider | Planned |
| Cursor background agents | Investigating |
| Custom / generic agents | Via HTTP API |

## Adding a Custom Agent

Any agent that can POST JSON to a localhost HTTP endpoint can integrate with NotchDeck.

The bridge accepts events at `http://localhost:PORT/hook` — see [architecture.md](architecture.md) for the payload schema.

## Contributing an Agent Adapter

Implement the `AgentProvider` protocol in `Sources/ClaudeNotchCore/Agent/` (this will move to `NotchDeckCore` as the rename progresses) and register it in `AgentRegistry.default`. See the existing `ClaudeAgentProvider` and `CodexAgentProvider` for reference.
