# NotchDeck Launch Checklist

## Pre-Launch (4-6 weeks)

### Week 1-2: Core Pro Implementation
- [ ] Create `NotchDeckPro` module with `LicenseManager`
- [ ] Gate themes (1 free, 4+ pro)
- [ ] Gate agent count (2 free, unlimited pro)
- [ ] Add preferences window with license entry
- [ ] Test free tier limits work correctly
- [ ] Test Pro activation works
- [ ] Update `Package.swift` dependencies

### Week 3-4: Pro Features
- [ ] Complete act-in-place decision UI
  - [ ] Permission approval cards
  - [ ] Question answer cards
  - [ ] Plan approval cards
  - [ ] Keyboard shortcuts (1/2/3/4)
  - [ ] "Answer in terminal" fallback
- [ ] Implement session history
  - [ ] SQLite or JSON persistence
  - [ ] 90-day retention
  - [ ] Search interface
  - [ ] Transcript export
- [ ] Build cost analytics
  - [ ] Weekly/monthly reports
  - [ ] Project-level breakdown
  - [ ] CSV export
  - [ ] Cost alerts (optional)
- [ ] Remembered decisions persistence
- [ ] Global hotkey (⌘⇧N)

### Week 5: Payment Setup
- [ ] Create Gumroad account
- [ ] Set up products:
  - [ ] NotchDeck Pro Monthly ($9)
  - [ ] NotchDeck Pro Annual ($79)
- [ ] Enable license key generation
- [ ] Test purchase flow (sandbox mode)
- [ ] Set up webhook endpoint (optional)
- [ ] Configure email templates

### Week 6: Marketing Assets
- [ ] Record demo video (2-3 min)
  - [ ] Show parallel agent workflow
  - [ ] Demonstrate click-to-jump
  - [ ] Show act-in-place decisions
  - [ ] Highlight Pro features
- [ ] Create 3-5 GIFs for social sharing
  - [ ] Notch expanding/contracting
  - [ ] Click-to-jump in action
  - [ ] Act-in-place approval
  - [ ] Multi-agent monitoring
  - [ ] Theme switching
- [ ] Take screenshots
  - [ ] Hero image (notch with 3-4 sessions)
  - [ ] Permission approval card
  - [ ] Cost tracking view
  - [ ] Theme gallery
  - [ ] Session history
- [ ] Update README
  - [ ] Add pricing table
  - [ ] Add demo GIF above fold
  - [ ] Link to demo video
  - [ ] Update feature list
- [ ] Create landing page (notchdeck.com)
  - [ ] Hero section
  - [ ] Demo video embed
  - [ ] Feature comparison table
  - [ ] Pricing (Free vs Pro)
  - [ ] Download + Buy CTAs
  - [ ] FAQ section
- [ ] Write launch blog post
  - [ ] "Why I built NotchDeck"
  - [ ] Problem: too many AI agents
  - [ ] Solution: unified dashboard
  - [ ] Show/don't tell (GIFs, video)
  - [ ] Call to action

---

## Beta Testing (2 weeks)

### Internal Testing (Week 1)
- [ ] Test on your own machine daily
- [ ] Run all 4-5 agents simultaneously
- [ ] Trigger all decision types
- [ ] Test free → Pro upgrade flow
- [ ] Test all themes
- [ ] Verify no memory leaks
- [ ] Check CPU usage (should be <2%)
- [ ] Test crash recovery

### External Beta (Week 2)
- [ ] Recruit 10-15 beta testers
  - [ ] 5 free tier users
  - [ ] 5 Pro users (give test keys)
  - [ ] 5 mixed (start free, upgrade mid-test)
- [ ] Provide beta test script:
  - [ ] Install from `.dmg`
  - [ ] Grant permissions (Automation, Accessibility)
  - [ ] Run 2-3 agents
  - [ ] Test click-to-jump
  - [ ] Trigger decisions (Pro users)
  - [ ] Report bugs, UX friction
- [ ] Collect feedback survey:
  - [ ] Is the free tier useful?
  - [ ] Is Pro worth $9/mo?
  - [ ] What features are missing?
  - [ ] Would you recommend to a friend?
  - [ ] Any bugs or crashes?
- [ ] Fix critical bugs
- [ ] Adjust feature split if needed

---

## Launch Day Prep (Week before)

### Code
- [ ] Bump version to 1.0.0
- [ ] Create Git tag: `v1.0.0`
- [ ] Build release binary:
  ```bash
  swift build -c release
  codesign --deep --force --verify --verbose --sign "Developer ID" \
    .build/release/NotchDeckApp
  ```
- [ ] Create `.dmg` installer
- [ ] Notarize with Apple:
  ```bash
  xcrun notarytool submit NotchDeck.dmg \
    --apple-id your@email.com \
    --password app-specific-password \
    --team-id TEAMID
  ```
- [ ] Staple notarization ticket:
  ```bash
  xcrun stapler staple NotchDeck.dmg
  ```
- [ ] Create GitHub Release
  - [ ] Upload `.dmg`
  - [ ] Write release notes
  - [ ] Include installation instructions

### Distribution
- [ ] Set Gumroad to live mode
- [ ] Test purchase flow end-to-end
- [ ] Verify license keys work
- [ ] Set up support email (support@notchdeck.com)
- [ ] Create auto-responder for support
- [ ] Set up analytics (Plausible, Simple Analytics, etc.)

### Marketing Content
- [ ] Schedule social posts:
  - [ ] Twitter/X thread (7-10 tweets)
  - [ ] LinkedIn post
  - [ ] Dev.to article
- [ ] Prepare HN submission:
  - [ ] Title: "NotchDeck – Monitor AI agents from your MacBook notch"
  - [ ] URL: GitHub repo or landing page
  - [ ] Post at 8-9 AM EST on weekday
- [ ] Prepare Reddit posts:
  - [ ] r/MacApps
  - [ ] r/ClaudeAI
  - [ ] r/MachineLearning (if allowed)
  - [ ] r/SideProject
- [ ] Notify relevant communities:
  - [ ] Claude Discord
  - [ ] OpenAI Developer Forum
  - [ ] MacAdmins Slack
  - [ ] Indie Hackers

---

## Launch Day (D-Day)

### Morning (8-9 AM EST)
1. [ ] Publish GitHub Release (v1.0.0)
2. [ ] Make Gumroad products live
3. [ ] Deploy landing page
4. [ ] Post on Hacker News
5. [ ] Post on Twitter/X (thread)
6. [ ] Post on Reddit (stagger by 2-3 hours)

### Throughout Day
- [ ] Monitor HN comments, reply within 30 min
- [ ] Monitor GitHub issues, respond quickly
- [ ] Monitor support email
- [ ] Track analytics:
  - [ ] GitHub stars
  - [ ] Website visits
  - [ ] Downloads
  - [ ] Purchases
- [ ] Share milestones:
  - [ ] "100 GitHub stars! 🎉"
  - [ ] "First Pro subscriber!"
  - [ ] "#1 on r/MacApps"

### Evening
- [ ] Post Product Hunt (next day if HN went well)
- [ ] Write launch day recap tweet
- [ ] Thank early supporters
- [ ] Plan follow-up content

---

## Post-Launch (First Month)

### Week 1
- [ ] Fix critical bugs reported by users
- [ ] Respond to all GitHub issues within 24h
- [ ] Respond to all support emails within 12h
- [ ] Monitor conversion rate (downloads → Pro)
- [ ] Write "Week 1" recap post

### Week 2-4
- [ ] Ship first patch release (1.0.1, 1.0.2)
- [ ] Add most-requested agent (Aider or Cursor)
- [ ] Add most-requested terminal (Ghostty or Alacritty)
- [ ] Collect testimonials from Pro users
- [ ] Add testimonials to landing page
- [ ] Write case study blog post
- [ ] Submit to:
  - [ ] Product Hunt (if not done at launch)
  - [ ] BetaList
  - [ ] MacUpdate
  - [ ] AlternativeTo

### Month 2-3
- [ ] Ship v1.1 with first major feature
- [ ] Consider Homebrew formula
- [ ] Start email newsletter (optional)
- [ ] Plan v2.0 roadmap with community input

---

## Success Metrics (First 6 Months)

### GitHub
- [ ] **500+ stars** (validates interest)
- [ ] **50+ forks** (community engagement)
- [ ] **20+ contributors** (ecosystem health)

### Users
- [ ] **200+ weekly active users** (free + pro)
- [ ] **20+ Pro subscribers** (by month 3)
- [ ] **5%+ conversion rate** (downloads → Pro)

### Revenue
- [ ] **$180/mo by month 3** (20 Pro users)
- [ ] **$500/mo by month 6** (50+ Pro users)
- [ ] Path to **$1k/mo by month 12**

### Community
- [ ] **10+ blog posts** from users
- [ ] **3+ YouTube tutorials** from community
- [ ] **50+ positive tweets** mentioning NotchDeck
- [ ] Active GitHub Discussions

---

## Emergency Rollback Plan

If launch goes wrong (critical bug, security issue):

1. [ ] **Take down download link immediately**
2. [ ] **Post GitHub issue explaining the problem**
3. [ ] **Email all Pro users with status update**
4. [ ] **Fix the issue**
5. [ ] **Release patch version**
6. [ ] **Test thoroughly before re-launching**
7. [ ] **Write post-mortem**

---

## Post-Launch Support Schedule

### First 2 weeks (intense)
- Check GitHub issues: **Every 4 hours**
- Check support email: **Every 4 hours**
- Monitor social mentions: **Twice daily**

### Month 1-3 (active)
- Check GitHub issues: **Twice daily**
- Check support email: **Once daily**
- Monitor social mentions: **Daily**

### Month 4+ (sustainable)
- Check GitHub issues: **Daily**
- Check support email: **Daily**
- Monitor social mentions: **Weekly**

---

## FAQ for Launch

**Q: Why open source the Pro code?**
A: Trust and community. Devs can audit security, contribute features, and see there's no telemetry.

**Q: Won't people just remove the license checks?**
A: Yes, and that's fine. We're targeting honest developers who support good tools.

**Q: What if I get overwhelmed with support?**
A: Set boundaries. Respond within 24h, not immediately. Point to docs first.

**Q: Should I discount Pro at launch?**
A: No. Charge full price from day 1. Discounts signal lack of confidence.

**Q: What if nobody buys Pro?**
A: That's okay! First 3 months are about validating free tier product-market fit. Pro sales come later.

**Q: Should I do a Product Hunt launch?**
A: Yes, but 1-2 weeks after initial launch. Let GitHub/HN users find bugs first.

---

## Key Reminders

✅ **Ship before you're ready** - v1.0 doesn't need every feature  
✅ **Talk to users** - DMs, emails, video calls  
✅ **Charge from day 1** - Free users don't validate willingness to pay  
✅ **Stay focused** - Don't add features until current ones work perfectly  
✅ **Be patient** - It takes 6-12 months to gain traction  

---

## Resources

- [Gumroad Setup Guide](https://help.gumroad.com/)
- [Mac App Notarization](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Launch on Hacker News](https://www.ycombinator.com/library/4D-a-guide-to-demo-day-and-hn-launches)
- [Indie Hackers](https://www.indiehackers.com/) - Community for solo founders
- [MicroConf](https://microconf.com/) - Bootstrapper community

---

Good luck with your launch! 🚀

Questions? Open a GitHub Discussion or email nav@notchdeck.com
