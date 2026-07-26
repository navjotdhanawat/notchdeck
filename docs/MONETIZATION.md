# NotchDeck Monetization Strategy

## Overview

NotchDeck uses a **freemium model** with an open-source core and gated Pro features. The entire codebase remains open (MIT licensed) but Pro features require a valid license key.

## Pricing

### Free Tier
- **Cost:** $0
- **Target:** Individual developers exploring AI agents
- **Value prop:** Core functionality, no credit card required

### Pro Tier
- **Monthly:** $9/month
- **Annual:** $79/year (save $29)
- **Target:** Power users running multiple agents daily
- **Value prop:** Unlimited agents, session history, act-in-place decisions, all themes

### Future: Team Tier (Phase 4)
- **Cost:** $29/user/month
- **Target:** Dev teams, agencies
- **Value prop:** Shared policies, audit logs, SSH relay, cost allocation

---

## Feature Matrix

| Feature | Free | Pro |
|---------|------|-----|
| **Core Monitoring** |
| Real-time session status | ✅ | ✅ |
| Click-to-jump terminal | ✅ | ✅ |
| Current session cost tracking | ✅ | ✅ |
| Completion sounds | ✅ | ✅ |
| Session retention | 30 min | 90 days |
| **Agents** |
| Claude Code | ✅ | ✅ |
| One additional agent | ✅ | ✅ |
| All agents (Codex, Aider, Cursor, etc) | ❌ | ✅ |
| Custom agent API | ❌ | ✅ |
| **Act-in-Place Decisions** |
| See permission requests | ✅ (view only) | ✅ |
| Approve/deny from notch | ❌ | ✅ |
| Answer prompts inline | ❌ | ✅ |
| Remembered decisions | ❌ | ✅ |
| **Cost Analytics** |
| Real-time session cost | ✅ | ✅ |
| Historical cost reports | ❌ | ✅ |
| Weekly/monthly summaries | ❌ | ✅ |
| Budget tracking & alerts | ❌ | ✅ |
| CSV export for billing | ❌ | ✅ |
| **Session Management** |
| Active sessions list | ✅ | ✅ |
| Session history (90 days) | ❌ | ✅ |
| Search past sessions | ❌ | ✅ |
| Export transcripts | ❌ | ✅ |
| Session templates | ❌ | ✅ |
| **Customization** |
| Themes | 1 (Graphite) | All 5+ |
| Custom color schemes | ❌ | ✅ |
| Custom sounds | ❌ | ✅ |
| Global hotkey | ❌ | ✅ |
| **Support** |
| Community (GitHub) | ✅ | ✅ |
| Email support | ❌ | ✅ |
| Feature request priority | ❌ | ✅ |

---

## Technical Implementation

### 1. Repository Structure

**Single monorepo** with Pro features gated behind license checks:

```
NotchDeck/
├── Sources/
│   ├── NotchDeckCore/          # Core domain logic (MIT)
│   ├── NotchDeckApp/           # Main app with free features (MIT)
│   ├── NotchDeckPro/           # Pro-only features (MIT, but gated)
│   │   ├── LicenseManager.swift
│   │   ├── SessionHistory/
│   │   ├── CostAnalytics/
│   │   ├── DecisionUI/
│   │   └── ThemeExtensions/
│   └── notch-bridge/           # CLI helper (MIT)
├── LICENSE                     # MIT License
└── README.md
```

**Why open-source the Pro code:**
- Builds trust (no hidden telemetry, security auditable)
- Encourages contributions (with agreement they remain Pro)
- Pro features aren't defensible IP—the integrated UX is the moat
- Reduces support burden (users can debug issues)

### 2. License Validation

Three-phase rollout for license checks:

#### Phase 1: Launch (Simple)
- Format check: `NOTCHDECK-PRO-{UUID}`
- Local validation only (no server calls)
- Easily bypassed, but that's OK—you're targeting honest developers

```swift
// LicenseManager.swift
private func validateLicense(_ key: String) -> Bool {
    // Simple pattern match
    let pattern = "^NOTCHDECK-PRO-[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}$"
    return key.range(of: pattern, options: .regularExpression) != nil
}
```

**Manual license generation:**
```bash
# Generate a license key
echo "NOTCHDECK-PRO-$(uuidgen)"
```

#### Phase 2: Growth (Online Validation)
- Integrate with Gumroad or LemonSqueezy
- License key → API call → validate & return user info
- Cache result locally (24h TTL)
- Graceful degradation if offline

```swift
private func validateLicense(_ key: String) async -> Bool {
    // Check cache first
    if let cached = cache[key], cached.expires > Date() {
        return cached.isValid
    }
    
    // Call validation API
    let url = URL(string: "https://api.notchdeck.com/v1/validate")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = try? JSONEncoder().encode(["license": key])
    
    do {
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ValidationResponse.self, from: data)
        
        // Cache for 24h
        cache[key] = CachedValidation(isValid: response.valid, expires: Date().addingTimeInterval(86400))
        return response.valid
    } catch {
        // Offline: trust cached result or allow 7-day grace period
        return cache[key]?.isValid ?? gracePeriodActive()
    }
}
```

#### Phase 3: Scale (Offline Signed Tokens)
- Server generates cryptographically signed JWT tokens
- App validates signature locally (no server call needed)
- Token includes: license key, tier, expiry, features
- Renewal checks happen weekly (silent background)

**Benefits:**
- Works 100% offline after initial activation
- Can't be easily bypassed (requires cracking RSA signature)
- Supports perpetual licenses with update cutoffs

### 3. Feature Gating in Code

**In UI code:**

```swift
// NotchController.swift
func onDecisionRequest(_ request: DecisionRequest) {
    if LicenseManager.shared.canUseActInPlace {
        // Show full decision card with action buttons
        showDecisionCard(request)
    } else {
        // Show "Pro feature" teaser with upgrade CTA
        showProTeaser(feature: "act-in-place", request: request)
        // Still show notification, but require terminal interaction
        focusTerminal(for: request.sessionKey)
    }
}
```

**In agent registry:**

```swift
// AgentRegistry.swift
public func activeProviders() -> [AgentProvider] {
    let limit = LicenseManager.shared.allowedAgentCount
    if limit >= all.count {
        return all  // Pro: unlimited
    }
    
    // Free: Claude Code + user's choice of one other
    let preferred = UserDefaults.standard.stringArray(forKey: "notchdeck.agents.free") ?? []
    let claude = all.first { $0.agentID == "claude" }!
    let others = all.filter { $0.agentID != "claude" && preferred.contains($0.agentID) }
    
    return [claude] + others.prefix(limit - 1)
}
```

**In theme store:**

```swift
// ThemeStore.swift
var availableThemes: [Theme] {
    if LicenseManager.shared.canUseAllThemes {
        return Themes.all
    }
    // Free: Only Graphite
    return [Themes.graphite]
}
```

### 4. Upgrade Flow UX

**In-app upgrade prompts** (non-intrusive):

1. **Decision teaser** - When act-in-place is triggered:
   ```
   ┌─────────────────────────────────────────┐
   │  🎯 Act-in-Place Decision (Pro)         │
   │                                         │
   │  Approve this Bash command without     │
   │  switching to your terminal.           │
   │                                         │
   │  [Upgrade to Pro - $9/mo] [Not now]   │
   └─────────────────────────────────────────┘
   ```

2. **Agent limit** - When user tries to add 3rd agent:
   ```
   You've reached the free tier limit (2 agents).
   
   Upgrade to Pro for unlimited agents.
   [Learn more]  [Upgrade]
   ```

3. **Theme selector** - Lock icon on premium themes:
   ```
   Themes:
   • Graphite (active)
   • Midnight 🔒 Pro
   • Nord 🔒 Pro
   
   [Unlock all themes with Pro]
   ```

4. **Menu bar** - Subtle "Upgrade" item:
   ```
   NotchDeck
   ├─ Preferences
   ├─ ──────────
   ├─ ✨ Upgrade to Pro
   ├─ ──────────
   └─ Quit
   ```

### 5. License Entry UI

**Simple preferences window:**

```swift
// PreferencesView.swift
VStack(alignment: .leading, spacing: 16) {
    if LicenseManager.shared.currentTier == .pro {
        // Active license
        Text("NotchDeck Pro")
            .font(.title2)
            .fontWeight(.bold)
        
        Text("Thank you for supporting NotchDeck! 🎉")
            .foregroundColor(.secondary)
        
        Button("Manage License") {
            // Open web portal or deactivate
        }
    } else {
        // Free tier - upgrade prompt
        Text("NotchDeck Free")
            .font(.title2)
        
        Text("Upgrade to Pro for unlimited agents, session history, and more.")
            .foregroundColor(.secondary)
        
        HStack {
            TextField("Enter license key", text: $licenseInput)
            Button("Activate") {
                LicenseManager.shared.setLicense(licenseInput)
            }
        }
        
        Button("Purchase License ($9/mo)") {
            NSWorkspace.shared.open(URL(string: "https://notchdeck.com/pro")!)
        }
        .buttonStyle(.borderedProminent)
    }
}
```

---

## Payment Processing

### Recommended: Gumroad or LemonSqueezy

**Why:**
- Dead simple setup (2FA + Stripe account)
- Handles VAT/sales tax automatically
- License key generation built-in
- Webhook for fulfillment
- 10% fee (worth it to avoid building payment infra)

**Setup:**

1. Create product on Gumroad:
   - Product name: "NotchDeck Pro"
   - Price: $9 (monthly) or $79 (annual)
   - Product type: License key
   - Enable "Generate license key on purchase"

2. Webhook endpoint (optional, for analytics):
   ```
   POST https://api.notchdeck.com/webhooks/gumroad
   {
     "sale_id": "...",
     "license_key": "NOTCHDECK-PRO-...",
     "email": "user@example.com",
     "price": 9
   }
   ```

3. In-app purchase flow:
   - User clicks "Upgrade to Pro"
   - Opens Safari to Gumroad checkout
   - After purchase, user receives email with license key
   - User enters key in app → validated → Pro unlocked

### Alternative: Paddle

**Better for:**
- Merchant of record (they handle all tax compliance)
- Higher volume (lower fees at scale)
- Native macOS SDK (in-app purchase flow)

**Drawback:**
- More complex setup
- Requires business entity (Gumroad works for individuals)

---

## Marketing & Distribution

### GitHub Releases
- Free: Full `.dmg` with all code
- Instructions to enter Pro license key in preferences
- Clearly label "Open source with paid Pro tier"

### Website (notchdeck.com)
- Hero: "Monitor AI agents from your notch"
- Feature comparison table (Free vs Pro)
- Pricing: $9/mo or $79/year
- "Download Free" CTA → GitHub releases
- "Buy Pro" CTA → Gumroad checkout

### Messaging
- **Free tier is not a trial** - it's fully functional forever
- Pro tier is for power users who want more
- "Support development" framing, not "unlock basic features"

---

## License File (Dual MIT + Commercial)

```
MIT License

Copyright (c) 2026 Navjot Dhanawat

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

Pro Features License Addendum

Pro-tier features (as marked in documentation) require a valid NotchDeck Pro
license. While the source code for Pro features is openly available under the
MIT License above, the *use* of Pro features in a compiled application requires
a license key obtained from https://notchdeck.com/pro.

This addendum does not restrict:
- Reading, studying, or modifying the source code
- Building the application for personal use
- Contributing changes back to the project

This addendum does restrict:
- Distributing compiled versions with Pro features unlocked without authorization
- Bypassing or removing license checks to enable Pro features for commercial use
```

---

## Implementation Checklist

### Phase 1: Foundation (Week 1-2)
- [ ] Create `NotchDeckPro/` module structure
- [ ] Implement `LicenseManager` with Phase 1 validation
- [ ] Add license entry UI in preferences
- [ ] Gate themes (free = 1, pro = all)
- [ ] Gate agent count (free = 2, pro = unlimited)
- [ ] Update README with pricing table
- [ ] Set up Gumroad product

### Phase 2: Core Pro Features (Week 3-4)
- [ ] Implement act-in-place decision UI (full cards with actions)
- [ ] Add session history persistence (SQLite or JSON)
- [ ] Build cost analytics views (weekly/monthly reports)
- [ ] Add remembered decisions persistence
- [ ] Create upgrade teasers for locked features

### Phase 3: Polish (Week 5-6)
- [ ] Add CSV export for sessions & costs
- [ ] Implement global hotkey
- [ ] Build session search
- [ ] Add email support inbox
- [ ] Create `/pro` landing page on website
- [ ] Set up webhook for license validation

### Phase 4: Launch (Week 7)
- [ ] Beta test with 10-20 users
- [ ] Create launch video (2-3 min)
- [ ] Write launch blog post
- [ ] Submit to Product Hunt
- [ ] Post on HN, Reddit, Twitter
- [ ] Monitor GitHub issues & support email

---

## Expected Metrics (6 months)

**Conservative:**
- 500 GitHub stars
- 200 active free users
- 10 Pro subscribers ($90/mo = $1,080/year)
- 5% free-to-pro conversion

**Optimistic:**
- 2,000 GitHub stars
- 1,000 active free users
- 80 Pro subscribers ($720/mo = $8,640/year)
- 8% conversion

**Realistic target:**
- $300-500/mo by month 6
- $1,000-2,000/mo by month 12
- Path to $5k/mo with team tier in year 2

---

## FAQ

### "Won't people just fork and remove the license checks?"

Yes, and that's fine. Your target market is developers—they could always pirate. But:
1. Most devs will pay $9/mo to support good tools
2. Pirates wouldn't have paid anyway (not lost revenue)
3. Open source builds trust & community contributions
4. Time cost of maintaining a fork > $9/mo for most people

### "Should I use a closed-source Pro version instead?"

No. Reasons:
1. Splits community (OSS contributors vs paying customers)
2. Reduces trust (what's in the binary?)
3. Harder to maintain (two codebases to sync)
4. Worse marketing (can't show full code on GitHub)

### "What about App Store distribution?"

Possible, but:
- **Pro:** Easier discovery, trusted payment, no Gumroad fee
- **Con:** 30% Apple cut, slower updates (review process), can't link to external payment for existing users
- **Decision:** Start with direct distribution, add App Store later if demand justifies it

### "When should I add a Team tier?"

Only after you have:
1. 50+ Pro subscribers (proves individual demand)
2. 5+ requests for team features
3. Bandwidth to build SSO, multi-seat management, etc.

Don't prematurely optimize for teams—nail the individual experience first.

---

## Next Steps

1. Review this document and adjust feature split if needed
2. Implement `LicenseManager` and gate 2-3 key features (themes, agents, act-in-place)
3. Set up Gumroad product
4. Update README with pricing table
5. Soft launch to 10 beta users, gather feedback
6. Public launch when act-in-place is solid

Questions? Open a GitHub Discussion or email nav@notchdeck.com
