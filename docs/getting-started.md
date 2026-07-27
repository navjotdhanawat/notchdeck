# Getting Started

## Requirements

- Apple Silicon Mac (M1 or later)
- macOS 14 Sonoma or later
- At least one supported AI coding agent installed (Claude Code, Codex CLI, etc.)
- At least one supported terminal (iTerm2, WezTerm, Kitty, or any terminal)

## Installation

### Option 1 — Homebrew Cask (Recommended)

```bash
brew install navjotdhanawat/notchdeck/notchdeck
```
*(Or tap first: `brew tap navjotdhanawat/notchdeck && brew install notchdeck`)*

### Option 2 — Terminal One-Liner (curl)

```bash
curl -fsSL https://notchdeck.app/api/install | bash
```
*Or via GitHub raw:*
```bash
curl -fsSL https://raw.githubusercontent.com/navjotdhanawat/notchdeck/main/install.sh | bash
```

### Option 3 — Download DMG Image

1. Download `NotchDeck.dmg` from [notchdeck.app](https://notchdeck.app) or [GitHub Releases](https://github.com/navjotdhanawat/notchdeck/releases)
2. Double-click `NotchDeck.dmg` and drag `NotchDeck.app` into `/Applications`
3. Launch `NotchDeck`

### Option 4 — Build from Source

```bash
git clone https://github.com/navjotdhanawat/notchdeck.git
cd notchdeck
swift build -c release
```

Copy `.build/release/NotchDeckApp` and `.build/release/notch-bridge` to `NotchDeck.app/Contents/MacOS/` (or use `./scripts/package.sh`).


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
