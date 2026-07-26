# Pro Feature Implementation Guide

This guide shows exactly how to integrate license gating into NotchDeck's existing codebase.

## Step 1: Update Package.swift

Add the Pro module:

```swift
// Package.swift
let package = Package(
    name: "NotchDeck",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/MrKai77/DynamicNotchKit.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "NotchDeckCore"),
        .target(
            name: "NotchDeckPro",
            dependencies: ["NotchDeckCore"]
        ),
        .executableTarget(
            name: "NotchDeckApp",
            dependencies: [
                "NotchDeckCore",
                "NotchDeckPro",  // Add this
                .product(name: "DynamicNotchKit", package: "DynamicNotchKit")
            ]
        ),
        .executableTarget(name: "notch-bridge", dependencies: ["NotchDeckCore"]),
        .testTarget(name: "NotchDeckCoreTests", dependencies: ["NotchDeckCore"])
    ],
    swiftLanguageModes: [.v5]
)
```

## Step 2: Gate Theme Selection

Modify `ThemeStore.swift`:

```swift
// Sources/NotchDeckApp/UI/ThemeStore.swift
import Foundation
import NotchDeckPro  // Add this import

final class ThemeStore {
    private let key = "notch.themeID"
    let all: [Theme] = Themes.all
    private(set) var current: Theme
    
    // Add this computed property
    var availableThemes: [Theme] {
        if LicenseManager.shared.canUseAllThemes {
            return all
        }
        // Free tier: Only Graphite
        return all.filter { $0.id == "graphite" }
    }
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.string(forKey: key)
        self.current = Themes.all.first { $0.id == saved } ?? Themes.default
        
        // Validate current theme is available
        if !availableThemes.contains(where: { $0.id == current.id }) {
            self.current = Themes.default
        }
    }
    
    private let defaults: UserDefaults
    
    @discardableResult
    func select(id: String) -> Theme {
        guard let t = all.first(where: { $0.id == id }) else { return current }
        
        // Check if theme is available in current tier
        if !availableThemes.contains(where: { $0.id == id }) {
            // Show upgrade prompt instead of changing theme
            return current
        }
        
        current = t
        defaults.set(id, forKey: key)
        return t
    }
}
```

## Step 3: Gate Agent Selection

Modify `AgentRegistry.swift`:

```swift
// Sources/NotchDeckCore/Agent/AgentRegistry.swift
import Foundation

public struct AgentRegistry {
    public let all: [any AgentProvider]
    
    public init(providers: [any AgentProvider]) {
        self.all = providers
    }
    
    // Add this method
    public func availableProviders() -> [any AgentProvider] {
        #if canImport(NotchDeckPro)
        import NotchDeckPro
        
        let maxAgents = LicenseManager.shared.allowedAgentCount
        if maxAgents >= all.count {
            return all  // Pro: all agents
        }
        
        // Free tier: Claude Code + user's choice of 1 other
        let preferredIDs = UserDefaults.standard.stringArray(forKey: "notchdeck.free.agents") ?? []
        
        // Always include Claude Code
        let claude = all.first { $0.agentID == "claude" }
        var result: [any AgentProvider] = claude.map { [$0] } ?? []
        
        // Add user's preferred agent (if set)
        if let preferredID = preferredIDs.first,
           let preferred = all.first(where: { $0.agentID == preferredID && $0.agentID != "claude" }) {
            result.append(preferred)
        } else {
            // Default to Codex as second agent
            if let codex = all.first(where: { $0.agentID == "codex" }) {
                result.append(codex)
            }
        }
        
        return result
        #else
        return all  // If Pro module not imported, allow all (for OSS builds)
        #endif
    }
    
    public static let `default` = AgentRegistry(providers: [
        ClaudeAgentProvider(),
        CodexAgentProvider()
    ])
}
```

## Step 4: Gate Act-in-Place Decisions

Modify `NotchController.swift`:

```swift
// Sources/NotchDeckApp/UI/NotchController.swift
import Foundation
import NotchDeckCore
import NotchDeckPro
import DynamicNotchKit

final class NotchController {
    // ... existing properties ...
    
    private var pendingDecisions: [DecisionRequest] = []
    
    func update(pending: [DecisionRequest]) {
        self.pendingDecisions = pending
        
        guard let first = pending.first else {
            // No pending decisions - contract to session list
            hideDecisionCard()
            return
        }
        
        if LicenseManager.shared.canUseActInPlace {
            // Pro: Show full interactive decision card
            showDecisionCard(first)
        } else {
            // Free: Show teaser with upgrade CTA
            showProTeaser(for: first)
        }
    }
    
    private func showDecisionCard(_ request: DecisionRequest) {
        // Full implementation: interactive buttons, keyboard shortcuts, etc.
        // (Your existing act-in-place UI)
    }
    
    private func showProTeaser(for request: DecisionRequest) {
        // Show a non-interactive preview with "Upgrade to Pro" button
        let view = VStack {
            Text("Act-in-Place Decision (Pro)")
                .font(.headline)
            
            Text(request.kind.description)
                .foregroundColor(.secondary)
                .padding()
            
            HStack(spacing: 12) {
                Button("Upgrade to Pro") {
                    NSWorkspace.shared.open(URL(string: "https://notchdeck.com/pro")!)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Open in Terminal") {
                    // Fall back to terminal interaction
                    self.onAnswerInTerminal?(request)
                }
                .buttonStyle(.bordered)
            }
        }
        
        // Show in notch
        notch.show(view)
    }
}
```

## Step 5: Add Preferences Window

Create new file `Sources/NotchDeckApp/UI/PreferencesWindow.swift`:

```swift
import SwiftUI
import NotchDeckPro

struct PreferencesView: View {
    @State private var licenseInput = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading) {
                    Text("NotchDeck")
                        .font(.title)
                        .fontWeight(.bold)
                    Text(tierLabel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.bottom)
            
            Divider()
            
            if LicenseManager.shared.currentTier == .pro {
                // Pro user view
                VStack(alignment: .leading, spacing: 12) {
                    Text("🎉 Thank you for supporting NotchDeck!")
                        .font(.headline)
                    
                    Text("You have access to all Pro features:")
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        FeatureBullet(text: "Unlimited agents")
                        FeatureBullet(text: "Act-in-place decisions")
                        FeatureBullet(text: "90-day session history")
                        FeatureBullet(text: "Cost analytics & reports")
                        FeatureBullet(text: "All themes & customization")
                    }
                    .padding(.leading)
                    
                    Button("Deactivate License") {
                        LicenseManager.shared.removeLicense()
                    }
                    .foregroundColor(.red)
                }
            } else {
                // Free user view
                VStack(alignment: .leading, spacing: 12) {
                    Text("Upgrade to Pro")
                        .font(.headline)
                    
                    Text("Unlock all features for $9/month or $79/year")
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        TextField("Enter license key", text: $licenseInput)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Activate") {
                            activateLicense()
                        }
                        .disabled(licenseInput.isEmpty)
                    }
                    
                    if showError {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button("Purchase License") {
                        NSWorkspace.shared.open(URL(string: "https://notchdeck.com/pro")!)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Divider()
            
            // Feature comparison
            DisclosureGroup("Compare Free vs Pro") {
                ComparisonTable()
            }
            
            Spacer()
        }
        .padding(24)
        .frame(width: 500, height: 450)
    }
    
    private var tierLabel: String {
        LicenseManager.shared.currentTier == .pro ? "Pro" : "Free"
    }
    
    private func activateLicense() {
        LicenseManager.shared.setLicense(licenseInput)
        
        if LicenseManager.shared.currentTier == .pro {
            // Success!
            showError = false
        } else {
            showError = true
            errorMessage = "Invalid license key. Please check and try again."
        }
    }
}

struct FeatureBullet: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 12))
            Text(text)
                .font(.subheadline)
        }
    }
}

struct ComparisonTable: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ComparisonRow(feature: "Active agents", free: "2", pro: "Unlimited")
            ComparisonRow(feature: "Session history", free: "30 min", pro: "90 days")
            ComparisonRow(feature: "Act-in-place", free: "–", pro: "✓")
            ComparisonRow(feature: "Cost analytics", free: "Basic", pro: "Full")
            ComparisonRow(feature: "Themes", free: "1", pro: "All")
        }
        .font(.caption)
        .padding(.top, 8)
    }
}

struct ComparisonRow: View {
    let feature: String
    let free: String
    let pro: String
    
    var body: some View {
        HStack {
            Text(feature)
                .frame(width: 120, alignment: .leading)
            Text(free)
                .frame(width: 80, alignment: .leading)
                .foregroundColor(.secondary)
            Text(pro)
                .frame(width: 80, alignment: .leading)
                .foregroundColor(.accentColor)
        }
    }
}
```

## Step 6: Add Menu Bar Item

Modify `AppCoordinator.swift`:

```swift
// Sources/NotchDeckApp/AppCoordinator.swift
import AppKit
import NotchDeckPro

@MainActor
public final class AppCoordinator: NSObject, NSApplicationDelegate {
    // ... existing properties ...
    
    private var preferencesWindow: NSWindow?
    
    private func setupMenuBar() {
        let menu = NSMenu()
        
        // App info
        menu.addItem(withTitle: "About NotchDeck", action: #selector(showAbout), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        
        // Preferences
        menu.addItem(withTitle: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        
        // Pro status/upgrade
        if LicenseManager.shared.currentTier == .pro {
            let proItem = NSMenuItem(title: "✓ Pro", action: nil, keyEquivalent: "")
            proItem.isEnabled = false
            menu.addItem(proItem)
        } else {
            menu.addItem(withTitle: "✨ Upgrade to Pro...", action: #selector(showUpgrade), keyEquivalent: "")
        }
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit NotchDeck", action: #selector(NSApplication.terminate), keyEquivalent: "q")
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = menu
        statusItem.button?.title = "NotchDeck"
    }
    
    @objc private func showPreferences() {
        if preferencesWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "NotchDeck Preferences"
            window.contentView = NSHostingView(rootView: PreferencesView())
            window.center()
            preferencesWindow = window
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showUpgrade() {
        NSWorkspace.shared.open(URL(string: "https://notchdeck.com/pro")!)
    }
    
    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
```

## Step 7: Update README

Add pricing section to `README.md`:

```markdown
## 💰 Pricing

NotchDeck is **open source** with a freemium model:

### Free Forever
- Monitor **Claude Code + 1 other agent**
- Real-time status & click-to-jump
- Current session cost tracking
- 30-minute session retention
- 1 theme (Graphite)

### Pro ($9/month or $79/year)
- **Unlimited agents** (Claude, Codex, Aider, Cursor, custom)
- **Act-in-place decisions** - Approve/deny from the notch
- **90-day session history** with search & export
- **Cost analytics** - Weekly/monthly reports, budgets, CSV export
- **All themes** + custom color schemes
- Global hotkey & advanced features

[**Try Free**](https://github.com/navjotdhanawat/notchdeck/releases) • [**Upgrade to Pro**](https://notchdeck.com/pro)

> 🤝 The entire codebase (including Pro features) is open source (MIT). Pro features require a license key to use.
```

## Step 8: Testing

Build and test the license flow:

```bash
# Build with Pro module
swift build -c release

# Test free tier
# 1. Launch app
# 2. Verify only 2 agents available
# 3. Verify only Graphite theme available
# 4. Trigger a decision → should show upgrade teaser

# Test Pro tier
# 1. Open Preferences
# 2. Enter test license: NOTCHDECK-PRO-12345678-1234-1234-1234-123456789ABC
# 3. Verify all agents available
# 4. Verify all themes available
# 5. Trigger decision → should show full interactive card
```

## Step 9: Beta Testing

Before public launch:

1. **Internal testing** (1 week)
   - Test on your own machine
   - Verify all gates work correctly
   - No crashes or hangs

2. **Beta testing** (2 weeks)
   - Invite 10-15 developers
   - Half use free, half use Pro (give them test keys)
   - Collect feedback on:
     - Are free tier limits reasonable?
     - Is Pro worth $9/month?
     - Any bugs or UX issues?

3. **Launch prep**
   - Set up Gumroad product
   - Create landing page at notchdeck.com/pro
   - Write launch blog post
   - Record demo video

## Common Issues

### "License not persisting after restart"
- Check `UserDefaults` permissions
- Verify app sandbox entitlements if sandboxed

### "All features unlocked in free tier"
- Ensure `NotchDeckPro` module is imported where gates are checked
- Verify `LicenseManager.shared.currentTier` returns `.free` without license

### "Can't build after adding Pro module"
- Run `swift package clean`
- Run `swift package resolve`
- Rebuild

## Next Steps

Once this is working:
1. Implement session history persistence (SQLite)
2. Build cost analytics views
3. Polish act-in-place decision cards
4. Set up Gumroad webhook for automatic license validation
5. Create `/pro` landing page
6. Launch! 🚀
