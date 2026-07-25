# Configuration

NotchDeck is designed to work out of the box with zero configuration. This page documents optional tuning.

## Hook Server Port

By default, `notch-bridge` posts events to `http://localhost:7779`. To change:

> 🚧 Preferences UI is coming soon. Port configuration will be available via right-click notch → Preferences.

For now, the default port (`7779`) is hardcoded in `Sources/ClaudeNotchCore/Config/BridgeConfig.swift`.

## Themes

NotchDeck ships with built-in themes that control notch appearance:

| Theme | Description |
|-------|-------------|
| `system` | Follows macOS light/dark mode |
| `dark` | Always dark, high contrast dots |
| `minimal` | Dots only, no session labels |
| `vibrant` | Glassmorphism background |

> 🚧 Theme switching via Preferences UI is coming soon.

## Sounds

A subtle completion chime plays when a session reaches `done` state.

> 🚧 Toggle in Preferences → Sounds (coming soon).

## Hook Files

NotchDeck auto-installs hooks on first launch. Manual paths:

- **Claude Code:** `~/.claude/settings.json` (hooks section)
- **Codex CLI:** Codex config directory (auto-detected)

> 🚧 **File → Reinstall Hooks** menu item is coming soon. To reinstall manually, delete the hooks from your agent config file and relaunch NotchDeck.

## Privacy

- All data stays local — no telemetry, no cloud sync, no accounts.
- The HTTP server binds to `127.0.0.1` only.
- Hook env vars forwarded by `notch-bridge` are allowlisted to the minimum set needed for terminal identification.
