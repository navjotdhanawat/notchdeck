# NotchDeck Strategic Roadmap

**Last Updated:** 2026-07-25  
**Vision:** Become the universal AI agent monitor for developers running parallel coding workflows

---

## 🎯 Current State Analysis

### What We've Built
- **Core Architecture**: Clean Swift 6 with protocol-driven design (`AgentProvider`, `TerminalJumping`, `DecisionMapping`)
- **Event Pipeline**: agent hooks → `notch-bridge` CLI → HTTP server → notch UI
- **Agent Support**: Claude Code, Codex CLI (extensible registry)
- **Terminal Support**: iTerm2, WezTerm, Kitty (precise pane jumping)
- **Key Features**: Real-time state, cost tracking, themes, sound notifications, auto-hook installation
- **Marketing Site**: Next.js 16 + Tailwind with interactive demos

### Strengths
1. **Perfect timing**: AI agents exploding; parallel workflows becoming standard
2. **Technical moat**: Deep terminal integration (pane-level jumping) is hard to replicate
3. **Clean architecture**: Extensible to new agents/terminals without core rewrites
4. **Local-first ethos**: Privacy-conscious developers appreciate this
5. **Act-in-place UX**: Reducing context switches is genuinely valuable

### Challenges
1. **Niche market**: Only MacBook Pro with notch (M1+ machines)
2. **Discovery**: Developers won't know they need this until they experience it
3. **Agent fragmentation**: Each new agent requires custom adapter code
4. **Monetization unclear**: Free/OSS or paid? Pricing model?
5. **Feature gaps**: Act-in-place shown in demos but implementation incomplete

---

## Phase 1: Complete & Launch v1.0 (4-6 weeks)

**Goal:** Ship a polished v1.0 that does one thing perfectly

### Critical Path Items

**Act-in-Place Completion**
- [ ] Finish decision UI for all three types (permission, question, plan)
- [ ] Keyboard shortcuts for decision cards (1/2/3/4 for quick answers)
- [ ] Ensure decision broker handles queue correctly
- [ ] Polish card animations and state transitions
- [ ] Handle edge cases (timeout, concurrent requests, app restart)

**Installation & Distribution**
- [ ] Build `.dmg` installer with code signing
- [ ] Apple notarization for Gatekeeper
- [ ] Homebrew formula draft (`brew install notchdeck`)
- [ ] Installation docs for terminal permission setup (iTerm2/WezTerm/Kitty)
- [ ] Troubleshooting guide (common errors, log locations)

**Marketing Assets**
- [ ] Demo video (90 seconds): parallel agents → notch updates → click to jump → approve from notch
- [ ] 3-5 GIFs for social sharing (specific workflows)
- [ ] "Why I built this" blog post for HN/Reddit
- [ ] Screenshot all demo images (replace placeholders in README)
- [ ] Update website with real screenshots

**Launch Activities**
- [ ] GitHub release with changelog
- [ ] Post to Hacker News
- [ ] Post to Reddit (r/ClaudeAI, r/LocalLLaMA, r/MachineLearning)
- [ ] Tweet thread with GIFs
- [ ] Set up GitHub Discussions for community

### Success Metrics
- 500+ GitHub stars within first month
- 100+ active users (telemetry opt-in)
- 20+ community discussions/issues with feature requests
- <5% crash rate

---

## Phase 2: Ecosystem Expansion (2-3 months)

**Goal:** Become the universal agent monitor

### New Agent Support

**High Priority**
- [ ] **Aider** - Popular with indie devs, simpler hook model
- [ ] **Cursor** - Huge user base (investigate background agent hooks)
- [ ] **Continue.dev** - VS Code extension, growing fast

**Medium Priority**
- [ ] **Gemini CLI** (Google) - Expand beyond Anthropic/OpenAI
- [ ] **Custom Agent API** - Documented HTTP endpoint for any tool

### New Terminal Support

**High Priority**
- [ ] **Ghostty** - New terminal, gaining traction, precise pane support
- [ ] **Alacritty** - Popular with Rust/systems devs

**Medium Priority**
- [ ] **Terminal.app improvements** - Better AppleScript for tab/window detection
- [ ] **Warp** - AI-native terminal (if hook API exists)

### Distribution & Growth
- [ ] Publish to Homebrew core tap
- [ ] Investigate Setapp (paid distribution channel)
- [ ] Product Hunt launch (after GitHub traction)
- [ ] Write integration guides for popular agents
- [ ] Create video tutorials (YouTube)

### Success Metrics
- 2,000+ GitHub stars
- 500+ weekly active users
- Agent mix: <50% Claude Code (shows ecosystem health)
- 5+ community-contributed agent adapters

---

## Phase 3: Power User Features (3-4 months)

**Goal:** Make NotchDeck indispensable for pro workflows

### Session Management
- [ ] **Session history** - Log all sessions, searchable archive
- [ ] **Session replay** - Review past transcript, tool usage
- [ ] **Export transcripts** - Markdown/JSON export for documentation
- [ ] **Session templates** - Pre-configured agent settings per project
- [ ] **Multi-machine sync** - iCloud sync of preferences, remembered decisions

### Cost Analytics
- [ ] **Weekly/monthly reports** - Spend trends, usage patterns
- [ ] **Project-level aggregation** - Tag sessions by project, client
- [ ] **Budget alerts** - Notify when approaching spend limits
- [ ] **Cost breakdown** - By agent, model, tool type
- [ ] **Export for billing** - CSV/JSON for client invoicing

### Workflow Enhancements
- [ ] **Global hotkey** - Show/hide notch with ⌘⇧N
- [ ] **Session filtering** - Hide done/failed, focus on active
- [ ] **Custom status scripts** - User-defined hooks for non-standard agents
- [ ] **Notification rules** - Slack/Discord webhooks when sessions complete
- [ ] **Quick actions** - Right-click session for common tasks (kill, restart, copy link)

### Quality of Life
- [ ] **Better error recovery** - Auto-reconnect on app restart
- [ ] **Stale session cleanup** - Auto-remove sessions inactive >30min
- [ ] **Onboarding flow** - First-run wizard for permissions, agent detection
- [ ] **Improved logging** - Structured logs, easier debugging
- [ ] **Crash reporting** - Opt-in telemetry for debugging (local-first)
- [ ] **Menu bar mode** - Fallback for users who dislike notch UI

### Success Metrics
- 5,000+ GitHub stars
- 1,000+ weekly active users
- 10%+ conversion to Pro (if paid tier launched)
- Average session time >30min (sticky usage)

---

## Phase 4: Team & Remote (6+ months)

**Goal:** Expand beyond individual developers

### Remote Work Support
- [ ] **SSH relay** - Monitor agents on remote boxes (dev servers, cloud VMs)
- [ ] **Tmux integration** - Jump to specific tmux panes over SSH
- [ ] **Docker/container awareness** - Track agents inside containers
- [ ] **VS Code Remote** - Integrate with VS Code Remote Development

### Team Features
- [ ] **Shared decision policies** - Team-level "always allow" rules
- [ ] **Cost allocation** - Tag sessions by project/client, export for billing
- [ ] **Audit logs** - Who approved what, when (compliance for agencies)
- [ ] **Team dashboard** - Web view of all team sessions (optional cloud component)

### Mobile Companion (iOS)
- [ ] **Push notifications** - Get alerted when agents need input
- [ ] **Remote approval** - Approve permissions from iPhone
- [ ] **Session monitoring** - View live status, cost burn
- [ ] **Relay server** - Secure bridge between Mac and iPhone (E2E encrypted)

### Success Metrics
- 10,000+ users
- 100+ teams (5+ users each)
- 20%+ revenue from team plans
- Mobile app: 1,000+ downloads

---

## Quick Wins (Do These Now)

**Immediate Actions** (1-2 days each)

1. **Fix screenshot placeholders** - Add real images or remove broken links
2. **Create demo GIF** - 10-second loop showing core workflow
3. **Record 90-second video** - Post to YouTube, embed in README
4. **Write launch blog post** - "Why I built NotchDeck" story
5. **Set up GitHub Discussions** - Enable community tab
6. **Add basic telemetry opt-in** - Anonymous usage stats (agent mix, features used)
7. **Create CONTRIBUTING.md** - Guide for agent adapter contributions
8. **Add changelog** - Start tracking releases properly

---

## North Star Metrics (6 Months)

If pursuing this as a solopreneur venture, track:

| Metric | Target | Why It Matters |
|--------|--------|----------------|
| GitHub stars | 500+ | Validates interest |
| Weekly active users | 200+ | Shows retention |
| Agent diversity | <50% Claude Code | Ecosystem health |
| Pro conversion | 5-10% | Revenue sustainability |
| Organic referrals | 30%+ new users | Word-of-mouth traction |
| Crash rate | <2% | Quality bar |
| Support load | <5 hrs/week | Scalability |

---

## Risk Mitigation

### Technical Risks
- **Notch UI polarizing** - Have fallback (menu bar mode, standalone window)
- **Agent APIs change** - Version hooks, maintain backwards compatibility
- **macOS updates break terminal APIs** - Test on betas, maintain adapter abstractions

### Market Risks
- **AI agent consolidation** - Focus on top 3-5 agents, extensible architecture
- **Competing products** - Move fast, build community, open-core option
- **Limited addressable market** - Expand to menu bar mode for non-notch Macs

### Business Risks
- **Monetization backlash** - Start OSS, transparent pricing, generous free tier
- **Support burden** - Good docs, community forums, FAQ
- **Burnout** - Scope phases realistically, don't overcommit

---

## Decision Points

### 3-Month Check-In
- **If stars <200**: Revisit positioning, double down on marketing
- **If retention <30%**: Core workflow has issues, talk to churned users
- **If agent mix is 80%+ Claude**: Prioritize Aider/Cursor support

### 6-Month Check-In
- **If users >1,000**: Consider monetization (Pro tier)
- **If growth plateaus**: Invest in content marketing, integrations
- **If revenue goal met**: Hire contract dev for mobile app

---

## What Success Looks Like

**1 Year Out:**
- 10,000+ GitHub stars
- 2,000+ weekly active users
- 5-10 community-maintained agent adapters
- $3-5K MRR (if monetized)
- Featured in developer newsletters, podcasts
- Acquired by AI dev tools company OR sustainable indie business

**The Vision:**
Every developer running parallel AI agents has NotchDeck in their notch. It's invisible when you don't need it, invaluable when you do. The "activity monitor for AI agents."

---

## Notes

- **Opinionated > Comprehensive**: Don't try to support every agent/terminal. Focus on top 3.
- **Ship regularly**: Monthly releases build momentum and community trust.
- **Talk to users obsessively**: Join Discord servers, Twitter, Reddit where agent users congregate.
- **Document decisions**: Keep ADRs (Architecture Decision Records) for major choices.
- **Stay lean**: Solo dev, nights/weekends → ruthless prioritization required.

---

*This is a living document. Update after each phase or major decision.*
