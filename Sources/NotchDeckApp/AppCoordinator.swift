import AppKit
import Foundation
import NotchDeckCore
import NotchDeckPro

@MainActor
public final class AppCoordinator: NSObject, NSApplicationDelegate {
    private let store = SessionStore()
    private let notch = NotchController()
    private let sound = SoundPlayer()
    private let registry = TerminalJumperRegistry(adapters: [ITerm2Jumper(), WezTermJumper(), KittyJumper()], fallback: FallbackActivator())
    private var server: HookServer?
    private var gcTimer: Timer?

    private let endedGrace: TimeInterval = 8
    private let staleTimeout: TimeInterval = 30 * 60

    private let broker = DecisionBroker(timeout: 300)
    private let remembered = RememberedDecisions()
    private let usage = UsageTracker(reader: FileTranscriptReader())
    private let agents = AgentRegistry.default
    private let themeStore = ThemeStore()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up the menu bar first so there's always a way to quit, even if the server fails to start.
        setupMenuBar()

        // Initialize auto-updater
        _ = UpdateManager.shared

        // Restore persisted license (no-op if no key saved; revalidates if >7 days old).
        Task { await LicenseManager.shared.activateIfStored() }

        let token = UUID().uuidString

        // 1. Start server (OS-assigned loopback port).
        let server = HookServer(
            token: token,
            agents: agents,
            onEvent: { [weak self] event in
                Task { @MainActor in self?.handle(event) }
            },
            onDecision: { [weak self] event, complete in
                guard let self else { return complete(.passthrough) }
                Task { await self.resolveDecision(event, complete) }
            })
        self.server = server
        guard let port = try? server.start() else {
            NSLog("NotchDeck: failed to start hook server"); return
        }

        // 2. Publish port + token for the helper.
        try? BridgeConfigWriter.write(BridgeConfig(port: port, token: token), to: Paths.bridgeConfigURL)

        // 3. Install hooks (idempotent), pointing at the sibling helper binary.
        if let helper = helperPath() { installHooks(helper: helper) }

        // 4. Route notch clicks to the right jumper.
        notch.onJump = { [weak self] session in
            Task { @MainActor in
                guard let self else { return }
                let result = await self.registry.jump(to: session.terminal)
                if case .failed = result {
                    self.sound.playError()
                    self.notch.showNotice("Couldn't focus that terminal window")
                }
            }
        }

        // 5. Bridge broker ↔ UI.
        notch.onDecide = { [weak self] req, decision in
            Task { await self?.broker.resolve(id: req.id, decision) }
        }
        // "Answer in terminal": focus the session's terminal, then let Claude show its own prompt.
        notch.onAnswerInTerminal = { [weak self] req in
            Task { @MainActor in
                guard let self else { return }
                if let session = self.store.session(forKey: req.sessionKey) {
                    let result = await self.registry.jump(to: session.terminal)
                    if case .failed = result {
                        self.sound.playError()
                        self.notch.showNotice("Couldn't focus that terminal — check Automation permission")
                    }
                } else {
                    self.notch.showNotice("No terminal on record for that session")
                }
                await self.broker.resolve(id: req.id, .passthrough)
            }
        }
        Task {
            await broker.setOnPendingChanged { [weak self] pending in
                Task { @MainActor in self?.notch.update(pending: pending) }
            }
        }

        // 6. GC timer.
        gcTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.collectGarbage() }
        }

        // 7. Apply the persisted theme before the first render.
        notch.setPalette(themeStore.current.palette)

        notch.update(store.snapshot())

        // 8. Present fullscreen interactive demo on first launch.
        if !UserDefaults.standard.bool(forKey: "notch.hasSeenOnboarding") {
            UserDefaults.standard.set(true, forKey: "notch.hasSeenOnboarding")
            openDemo()
        }
    }

    private func handle(_ event: HookEvent) {
        let provider = agents.provider(for: event.agentID)
        let effects = store.apply(event, provider: provider)
        effects.forEach(sound.play)
        notch.update(store.snapshot())
        if event.name == .sessionEnd {
            let endKey = TerminalIdentifierRegistry.default.key(for: event.env, sessionID: event.sessionID)
            remembered.clear(sessionKey: endKey)
            if let path = event.transcriptPath, !path.isEmpty {
                Task { [weak self] in await self?.usage.forget(transcriptPath: path) }
            }
        }
        if event.name != .sessionEnd, let path = event.transcriptPath, !path.isEmpty {
            let key = TerminalIdentifierRegistry.default.key(for: event.env, sessionID: event.sessionID)
            Task { [weak self] in
                guard let self else { return }
                let u = await self.usage.update(transcriptPath: path,
                                                parser: provider.transcriptParser,
                                                estimator: provider.costEstimator)   // off-main on the actor
                self.store.updateUsage(sessionKey: key, u)              // back on MainActor
                self.notch.update(self.store.snapshot())
            }
        }
    }

    private func collectGarbage() {
        store.purge(now: Date(), endedGrace: endedGrace, staleTimeout: staleTimeout)
        notch.update(store.snapshot())
    }

    private func installHooks(helper: String) {
        for provider in agents.presentProviders() {
            let profile = provider.installProfile
            let decisionsOn = decisionsEnabled(for: profile.versionGate)
            let specs = profile.monitorSpecs + (decisionsOn ? profile.decisionSpecs : [])
            try? HookInstaller(helperPath: helper, specs: specs, backupFilename: profile.backupFilename)
                .install(into: profile.settingsURL)
        }
    }

    private func uninstallHooks(helper: String) {
        for provider in agents.presentProviders() {
            let profile = provider.installProfile
            try? HookInstaller(helperPath: helper, specs: profile.monitorSpecs + profile.decisionSpecs,
                               backupFilename: profile.backupFilename)
                .uninstall(from: profile.settingsURL)
        }
    }

    /// Nil gate ⇒ decisions always on (an agent too old to support hooks ignores its hooks file entirely).
    private func decisionsEnabled(for gate: VersionGate?) -> Bool {
        guard let gate else { return true }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = [gate.binary, "--version"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run(); p.waitUntilExit() } catch { return false }
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return CLIVersion.meetsMinimum(out, gate.minVersion)
    }

    private func resolveDecision(_ event: HookEvent, _ complete: @escaping (Decision) -> Void) async {
        // AskUserQuestion is answered via its own synchronous PreToolUse decide hook. In normal
        // permission mode a PermissionRequest may ALSO fire for it — pass through so we don't
        // show a stray allow/deny card on top of the question card.
        if event.name == .permissionRequest, event.toolName == "AskUserQuestion" {
            return complete(.passthrough)
        }
        let provider = agents.provider(for: event.agentID)
        let sessionKey = TerminalIdentifierRegistry.default.key(for: event.env, sessionID: event.sessionID)
        guard let request = provider.decisionMapper.request(from: event, id: UUID().uuidString, sessionKey: sessionKey) else {
            return complete(.passthrough)
        }
        if case let .toolPermission(tool, _) = request.kind,
           remembered.isAllowed(sessionKey: request.sessionKey, tool: tool) {
            return complete(.allow(scope: .session))
        }
        let decision = await broker.decide(request)
        if case .allow(scope: .session) = decision,
           case let .toolPermission(tool, _) = request.kind {
            remembered.remember(sessionKey: request.sessionKey, tool: tool)
        }
        complete(decision)
    }

    private func helperPath() -> String? {
        // notch-bridge sits next to the app executable (same .build dir or bundle Helpers dir).
        guard let dir = Bundle.main.executableURL?.deletingLastPathComponent() else { return nil }
        let candidate = dir.appendingPathComponent("notch-bridge").path
        return FileManager.default.fileExists(atPath: candidate) ? candidate : nil
    }

    // MARK: - Menu bar

    private var statusItem: NSStatusItem?
    private var themeMenu: NSMenu?
    private var animThemeMenu: NSMenu?
    private var licenseMenuItem: NSMenuItem?

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "◗"
        let menu = NSMenu()

        let demoItem = menu.addItem(withTitle: "✨ Live Notch Demo", action: #selector(openDemo), keyEquivalent: "")
        menu.addItem(.separator())

        let reinstallItem = menu.addItem(withTitle: "Reinstall hooks", action: #selector(reinstall), keyEquivalent: "")
        let uninstallItem = menu.addItem(withTitle: "Uninstall hooks", action: #selector(uninstall), keyEquivalent: "")
        let clearApprovalsItem = menu.addItem(withTitle: "Clear remembered approvals", action: #selector(clearApprovals), keyEquivalent: "")
        let soundItem = NSMenuItem(title: "Sound", action: #selector(toggleSound), keyEquivalent: "")
        soundItem.state = sound.enabled ? .on : .off
        menu.addItem(soundItem)

        let pixelArtItem = NSMenuItem(title: "Pixel Art Animations", action: #selector(togglePixelArt), keyEquivalent: "")
        pixelArtItem.state = notch.isPixelArtEnabled ? .on : .off
        menu.addItem(pixelArtItem)

        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu()
        for theme in themeStore.all {
            let ti = NSMenuItem(title: theme.name, action: #selector(selectTheme(_:)), keyEquivalent: "")
            ti.target = self
            ti.representedObject = theme.id
            ti.state = (theme.id == themeStore.current.id) ? .on : .off
            themeMenu.addItem(ti)
        }
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)
        self.themeMenu = themeMenu

        let animThemeItem = NSMenuItem(title: "Animation Theme", action: nil, keyEquivalent: "")
        let animThemeMenu = NSMenu()
        for animTheme in AnimationTheme.allCases {
            let ti = NSMenuItem(title: animTheme.name, action: #selector(selectAnimationTheme(_:)), keyEquivalent: "")
            ti.target = self
            ti.representedObject = animTheme.rawValue
            ti.state = (animTheme == notch.currentAnimationTheme) ? .on : .off
            animThemeMenu.addItem(ti)
        }
        animThemeItem.submenu = animThemeMenu
        menu.addItem(animThemeItem)
        self.animThemeMenu = animThemeMenu

        // License section
        let licenseItem = NSMenuItem(title: licenseMenuTitle(), action: #selector(activateLicense), keyEquivalent: "")
        licenseItem.target = self
        menu.addItem(licenseItem)
        self.licenseMenuItem = licenseItem

        let deactivateItem = menu.addItem(withTitle: "Deactivate License", action: #selector(deactivateLicense), keyEquivalent: "")
        deactivateItem.target = self

        menu.addItem(.separator())

        // Updates section
        let updateItem = menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit NotchDeck", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        // Only the custom-action items target self. The Quit item is intentionally left
        // targetless so terminate(_:) routes through the responder chain to NSApp — the app
        // runs as .accessory (no standard app menu / ⌘Q), so this menu is the only way to quit.
        [demoItem, reinstallItem, uninstallItem, clearApprovalsItem, soundItem, pixelArtItem].forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func openDemo() {
        LiveNotchDemoEngine.shared.startDemo(
            notchController: notch,
            themeStore: themeStore,
            soundPlayer: sound
        )
    }

    @objc private func checkForUpdates() {
        UpdateManager.shared.checkForUpdates(self)
    }

    private func licenseMenuTitle() -> String {
        switch LicenseManager.shared.currentTier {
        case .pro: return "License: Pro ✓"
        case .free: return "Activate License…"
        }
    }

    @objc private func activateLicense() {
        guard LicenseManager.shared.currentTier == .free else { return }
        let alert = NSAlert()
        alert.messageText = "Activate NotchDeck Pro"
        alert.informativeText = "Enter your license key (NDPRO-XXXX-XXXX-XXXX):"
        alert.addButton(withTitle: "Activate")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "NDPRO-XXXX-XXXX-XXXX"
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let key = input.stringValue.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        Task {
            do {
                try await LicenseManager.shared.activate(key)
                await MainActor.run { self.licenseMenuItem?.title = self.licenseMenuTitle() }
                let ok = NSAlert()
                ok.messageText = "License Activated"
                ok.informativeText = "Welcome to NotchDeck Pro!"
                ok.runModal()
            } catch {
                let err = NSAlert()
                err.messageText = "Activation Failed"
                err.informativeText = error.localizedDescription
                err.alertStyle = .warning
                err.runModal()
            }
        }
    }

    @objc private func deactivateLicense() {
        guard LicenseManager.shared.currentTier == .pro else { return }
        let alert = NSAlert()
        alert.messageText = "Deactivate License"
        alert.informativeText = "This will remove your Pro license from this Mac."
        alert.addButton(withTitle: "Deactivate")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        LicenseManager.shared.deactivate()
        licenseMenuItem?.title = licenseMenuTitle()
    }

    @objc private func reinstall() {
        if let helper = helperPath() { installHooks(helper: helper) }
    }
    @objc private func uninstall() {
        if let helper = helperPath() { uninstallHooks(helper: helper) }
    }
    @objc private func clearApprovals() {
        remembered.clearAll()
    }
    @objc private func toggleSound(_ item: NSMenuItem) {
        sound.enabled.toggle(); item.state = sound.enabled ? .on : .off
    }
    @objc private func togglePixelArt(_ item: NSMenuItem) {
        notch.togglePixelArt()
        item.state = notch.isPixelArtEnabled ? .on : .off
    }
    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        let theme = themeStore.select(id: id)
        notch.setPalette(theme.palette)
        // refresh checkmarks
        themeMenu?.items.forEach { $0.state = ($0.representedObject as? String == theme.id) ? .on : .off }
    }
    @objc private func selectAnimationTheme(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let theme = AnimationTheme(rawValue: raw) else { return }
        notch.selectAnimationTheme(theme)
        // refresh checkmarks
        animThemeMenu?.items.forEach { $0.state = ($0.representedObject as? String == theme.rawValue) ? .on : .off }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        gcTimer?.invalidate()
        server?.stop()
    }
}
