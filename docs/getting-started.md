# Getting Started

## Requirements

- Apple Silicon Mac (M1 or later)
- macOS 14 Sonoma or later
- At least one supported AI coding agent installed (Claude Code, Codex CLI, etc.)
- At least one supported terminal (iTerm2, WezTerm, Kitty, or any terminal)

## Installation

> 📦 Pre-built releases coming soon. For now, build from source.

### Build from Source

```bash
git clone https://github.com/navjotdhanawat/notchdeck.git
cd notchdeck
swift build -c release
```

Copy the built app to your Applications folder and launch it.

## First Run

1. Launch **NotchDeck** — it will appear in your MacBook notch area.
2. On first launch, NotchDeck will auto-detect which agents are installed and configure hooks automatically.
3. Open a new terminal session and start an AI agent (e.g. `claude` or `codex`).
4. NotchDeck will immediately begin showing session status in the notch.

## Click to Jump

Click any session badge in the notch to instantly focus that terminal window/tab/pane. No yabai required.

## Next Steps

- [Configuration →](configuration.md) — customize ports, themes, sounds
- [Supported Agents →](agents.md) — full list of supported agents and hook setup
- [Supported Terminals →](terminals.md) — terminal-specific jump behavior
