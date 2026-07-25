# Supported Terminals

NotchDeck uses a `TerminalIdentifying` + `TerminalJumping` protocol pair — each terminal adapter reads hook env vars to identify a session and uses terminal-specific APIs to jump to it.

## Currently Supported

### iTerm2 ✅
- **Jump mechanism:** AppleScript — focuses exact window → tab → split pane
- **Required env var:** `ITERM_SESSION_ID`
- **Priority:** Highest (100)
- **Notes:** Most precise jump behavior; recommended for Claude Code users

### WezTerm ✅
- **Jump mechanism:** `wezterm cli` CLI commands
- **Required env var:** `WEZTERM_PANE`
- **Priority:** 90

### Kitty ✅
- **Jump mechanism:** `kitty @` remote control
- **Required env var:** `KITTY_WINDOW_ID`
- **Priority:** 90

### Generic / Any Terminal ✅
- **Jump mechanism:** App-raise (brings terminal to front, no pane precision)
- **Required env var:** `TERM_PROGRAM`
- **Priority:** Lowest (fallback)
- **Supported terminals:** Terminal.app, Ghostty, Alacritty, Hyper, and any terminal that sets `TERM_PROGRAM`

## Planned

| Terminal | Status |
|----------|--------|
| Ghostty (precise jump) | Planned |
| VS Code integrated terminal | Investigating |
| SSH remote sessions | Planned (v2) |

## Adding a Terminal Adapter

Implement `TerminalIdentifying` (for detection) and a conformer of `TerminalJumping` (for focus) in `Sources/ClaudeNotchCore/Terminal/`. Register in `TerminalIdentifierRegistry`.
