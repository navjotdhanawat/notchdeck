# ClaudeNotch

A native macOS app that turns the MacBook notch into a live status monitor for **parallel Claude Code CLI sessions** — a focused, open, yabai-free take on "Vibe Island."

At a glance, see which of your running Claude Code sessions is **working**, **needs input**, **needs permission**, is **done**, or **failed** — and click to jump straight to the exact iTerm2 pane it runs in.

> Status: design complete, implementation not started. Local-only project.

## How it works

Claude Code fires **hooks** on session events. A tiny bundled helper (`notch-bridge`) forwards each event — plus the terminal's `ITERM_SESSION_ID` — to a localhost HTTP server inside the app, which drives a [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) notch UI. Clicking a session focuses its exact iTerm2 window→tab→split via AppleScript. No yabai, no cloud, no telemetry.

See [`docs/superpowers/specs/2026-07-22-claudenotch-design.md`](docs/superpowers/specs/2026-07-22-claudenotch-design.md) for the full design.

## Scope

- **v1:** Claude Code + iTerm2, glanceable state monitor, precise click-to-jump, completion sound, self-configuring hooks.
- **v2+ (designed for, not yet built):** approve/answer in place, usage/cost tracking, more agents (Codex/Gemini), more terminals, SSH remote, mobile relay.

## Requirements

- Apple-Silicon Mac, macOS 14+
- iTerm2 (v1 precise-jump target)
- Claude Code
