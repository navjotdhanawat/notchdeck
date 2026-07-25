# Contributing

Contributions are welcome! NotchDeck is designed to be extensible — the two most common contribution types are **new agent adapters** and **new terminal adapters**.

## Development Setup

```bash
git clone https://github.com/navjotdhanawat/notchdeck.git
cd notchdeck
xed .               # opens in Xcode
# or: swift build
```

**Requirements:** Xcode 16+, Swift 6, macOS 14+

## Project Structure

```
Sources/
├── NotchDeckCore/       # core library (agents, sessions, terminals, domain logic)
│   ├── Agent/            # AgentProvider implementations + protocols
│   ├── Config/           # paths, config constants
│   ├── Domain/           # session store, transcript parsing, decisions
│   ├── Install/          # hook installer, CLI version detection
│   ├── Model/            # Session, HookEvent, TerminalIdentity, etc.
│   └── Terminal/         # TerminalIdentifying + TerminalJumping implementations
├── NotchDeckApp/        # macOS SwiftUI app
│   ├── UI/               # notch components, themes, palette
│   ├── Sound/            # completion sounds
│   └── Transport/        # HTTP server
└── notch-bridge/         # tiny CLI binary — reads stdin, POSTs to localhost
web/                      # Next.js landing page
docs/                     # documentation (you are here)
```

## Adding an Agent

1. Create a new folder under `Sources/NotchDeckCore/Agent/YourAgent/`
2. Implement `AgentProvider` — at minimum `agentID`, `displayName`, `isPresent()`, `installProfile`, `decisionMapper`, `transcriptParser`, `costEstimator`, `toolRenderer`
3. Register in `AgentRegistry.default`
4. Add docs entry in `docs/agents.md`

See `ClaudeAgentProvider.swift` and `CodexAgentProvider.swift` for reference.

## Adding a Terminal

1. Implement `TerminalIdentifying` in `Sources/ClaudeNotchCore/Terminal/`
2. Implement `TerminalJumping` for your terminal
3. Register in `TerminalIdentifierRegistry`
4. Add docs entry in `docs/terminals.md`

## Running Tests

```bash
swift test
```

## Code Style

- Swift 5 language mode (Swift 6 concurrency where applicable)
- No force unwraps in new code — use `guard` or `if let`
- New protocols go in the same file as their primary implementation if small, or their own file if substantial
- Keep `notch-bridge` dependency-free (it must stay tiny)

## Submitting a PR

- Branch from `main`
- Keep PRs focused — one feature or fix per PR
- Update `docs/` if your change affects user-facing behavior
- Include a brief description of what changed and why
