import SwiftUI
import Combine
import NotchDeckCore
import NotchDeckPro

public struct GuidedScenarioStep: Equatable {
    public let id: Int
    public let title: String
    public let subtitle: String
    public let actionHint: String
    public let badgeText: String
}

public struct DemoTerminalWindow: Identifiable, Equatable {
    public var id: String { sessionKey }
    public let sessionKey: String
    public let appName: String
    public let projectName: String
    public let cwd: String
    public var logs: [MockTerminalLine]
}

@MainActor
final class LiveNotchDemoEngine: ObservableObject {
    static let shared = LiveNotchDemoEngine()

    @Published private(set) var isRunning: Bool = false
    @Published private(set) var currentStepIndex: Int = 0
    @Published private(set) var currentStep: GuidedScenarioStep?
    @Published private(set) var activeFocusSessionKey: String = "demo-s1"
    @Published private(set) var jumpFocusEffect: Bool = false
    @Published private(set) var lastSoundPlayed: String? = nil
    @Published private(set) var activeThemeID: String = "graphite"

    @Published private(set) var terminalWindows: [DemoTerminalWindow] = []

    private var notchController: NotchController?
    private var themeStore: ThemeStore?
    private var soundPlayer: SoundPlayer?
    private var backdropWindow: DemoBackdropWindow?

    private var originalThemeID: String = "graphite"
    private var tokenTickerTimer: Timer?
    private var tickCount: Int = 0

    public static let steps: [GuidedScenarioStep] = [
        GuidedScenarioStep(
            id: 0,
            title: "Live Multi-Agent Command Deck",
            subtitle: "NotchDeck turns your MacBook notch into a live status dashboard for active Claude Code & Codex sessions.",
            actionHint: "Hover your cursor over the top notch to expand the status deck",
            badgeText: "Session Monitoring"
        ),
        GuidedScenarioStep(
            id: 1,
            title: "In-Notch Tool Permission Workflows",
            subtitle: "When an agent requests command execution (Bash, Git, Edit), a card expands right in your notch.",
            actionHint: "Click 'Allow Once' or 'Deny' directly on the notch card above",
            badgeText: "Tool Permission"
        ),
        GuidedScenarioStep(
            id: 2,
            title: "Interactive Agent Questions",
            subtitle: "Answer multi-choice prompt questions directly from the notch without switching away from your active code.",
            actionHint: "Select an option on the notch card to send your answer",
            badgeText: "Prompt Questions"
        ),
        GuidedScenarioStep(
            id: 3,
            title: "Implementation Plan Approval",
            subtitle: "Review proposed architectural changes and step-by-step code diffs inside the expanded notch card.",
            actionHint: "Click 'Approve Plan' or 'Request Changes' on the card",
            badgeText: "Plan Review"
        ),
        GuidedScenarioStep(
            id: 4,
            title: "One-Click Terminal Jump Precision",
            subtitle: "Click any session card in the notch to instantly focus its exact terminal window and pane across iTerm2, WezTerm, or Kitty.",
            actionHint: "Click a session row or terminal window below to test focus jumping",
            badgeText: "Click-To-Jump"
        ),
        GuidedScenarioStep(
            id: 5,
            title: "10 Curated Themes & Audio Chimes",
            subtitle: "Customize your command deck's look with vibrant HSL color palettes and distinct audio feedback for completions and failures.",
            actionHint: "Select a theme pill below to recolor the notch deck live",
            badgeText: "Theme & Sound Studio"
        )
    ]

    func startDemo(
        notchController: NotchController,
        themeStore: ThemeStore,
        soundPlayer: SoundPlayer
    ) {
        guard !isRunning else { return }
        self.notchController = notchController
        self.themeStore = themeStore
        self.soundPlayer = soundPlayer
        self.originalThemeID = themeStore.current.id
        self.activeThemeID = themeStore.current.id

        isRunning = true
        currentStepIndex = 0

        setupDemoTerminalWindows()

        // Wire notch interactions
        notchController.onJump = { [weak self] session in
            Task { @MainActor in self?.triggerTerminalJump(session.key) }
        }
        notchController.onDecide = { [weak self] request, decision in
            Task { @MainActor in self?.handleNotchDecision(request, decision: decision) }
        }

        // Show native full desktop wallpaper window
        let backdrop = DemoBackdropWindow(
            engine: self,
            onExit: { [weak self] in
                Task { @MainActor in self?.stopDemo() }
            }
        )
        backdrop.show()
        self.backdropWindow = backdrop

        // Start Stage 0
        runStage(0)
    }

    func stopDemo() {
        guard isRunning else { return }
        tokenTickerTimer?.invalidate()
        tokenTickerTimer = nil

        backdropWindow?.closeWindow()
        backdropWindow = nil

        if let themeStore {
            let restored = themeStore.select(id: originalThemeID)
            notchController?.setPalette(restored.palette)
        }
        notchController?.update([])
        notchController?.update(pending: [])

        isRunning = false
    }

    func nextStage() {
        if currentStepIndex + 1 < Self.steps.count {
            runStage(currentStepIndex + 1)
        } else {
            stopDemo()
        }
    }

    func prevStage() {
        if currentStepIndex > 0 {
            runStage(currentStepIndex - 1)
        }
    }

    func selectTheme(_ themeID: String) {
        activeThemeID = themeID
        if let themeStore {
            let theme = themeStore.select(id: themeID)
            notchController?.setPalette(theme.palette)
            soundPlayer?.play(.soundDone)
            lastSoundPlayed = "Glass (Completion Chime)"
        }
    }

    func triggerTerminalJump(_ sessionKey: String) {
        activeFocusSessionKey = sessionKey
        jumpFocusEffect = true
        soundPlayer?.play(.soundDone)
        lastSoundPlayed = "Glass (Jump Chime)"
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            jumpFocusEffect = false
        }
    }

    func playSoundTest(_ effect: SessionEffect) {
        soundPlayer?.play(effect)
        lastSoundPlayed = (effect == .soundFailed) ? "Basso (Failure Chime)" : "Glass (Completion Chime)"
    }

    func playErrorSoundTest() {
        soundPlayer?.playError()
        lastSoundPlayed = "Funk (Error Alert)"
    }

    private func setupDemoTerminalWindows() {
        terminalWindows = [
            DemoTerminalWindow(
                sessionKey: "demo-s1",
                appName: "iTerm2",
                projectName: "frontend-web",
                cwd: "~/workspace/frontend-web",
                logs: [
                    MockTerminalLine(timestamp: "15:42:01", prompt: "frontend-web $ ", text: "claude code --prompt 'Refactor Navigation UI'", type: .input),
                    MockTerminalLine(timestamp: "15:42:05", prompt: "claude > ", text: "Analyzing NavigationBar.tsx for accessibility...", type: .output),
                    MockTerminalLine(timestamp: "15:42:12", prompt: "claude > ", text: "Editing 3 components: Header, NavigationBar, ThemeToggle", type: .tool)
                ]
            ),
            DemoTerminalWindow(
                sessionKey: "demo-s2",
                appName: "WezTerm",
                projectName: "database-engine",
                cwd: "~/workspace/database-engine",
                logs: [
                    MockTerminalLine(timestamp: "15:40:10", prompt: "database-engine $ ", text: "codex run --prompt 'Optimize Query Planner'", type: .input),
                    MockTerminalLine(timestamp: "15:41:22", prompt: "codex > ", text: "Optimized B-tree index lookup routines", type: .output),
                    MockTerminalLine(timestamp: "15:41:50", prompt: "codex > ", text: "✓ 48/48 integration tests passed (1.2s)", type: .success)
                ]
            )
        ]
    }

    func runStage(_ index: Int) {
        currentStepIndex = index
        currentStep = Self.steps[index]
        tokenTickerTimer?.invalidate()

        switch index {
        case 0:
            stageMultiAgentDeck()
        case 1:
            stageToolPermissionCard()
        case 2:
            stageQuestionCard()
        case 3:
            stagePlanApprovalCard()
        case 4:
            stageTerminalJump()
        case 5:
            stageThemeAndSoundStudio()
        default:
            stopDemo()
        }
    }

    // MARK: - Stage 0: Glanceable Deck
    private func stageMultiAgentDeck() {
        let now = Date()
        let session1 = Session(
            key: "demo-s1",
            agentID: "claude",
            agentSessionID: "claude-demo",
            terminal: TerminalIdentity(adapterID: "iterm2", handle: "tab-1", appName: "iTerm2"),
            cwd: "/Users/dev/workspace/frontend-web",
            title: "Refactor Navigation UI",
            state: .working,
            currentTool: "Edit",
            currentAction: "Refactoring NavigationBar.tsx",
            stateSince: now.addingTimeInterval(-35),
            usage: SessionUsage(model: "claude-sonnet-5", tokens: TokenUsage(input: 42_100, output: 8_400), costUSD: 0.16),
            startedAt: now.addingTimeInterval(-120),
            lastEventAt: now
        )

        let session2 = Session(
            key: "demo-s2",
            agentID: "codex",
            agentSessionID: "codex-demo",
            terminal: TerminalIdentity(adapterID: "wezterm", handle: "pane-1", appName: "WezTerm"),
            cwd: "/Users/dev/workspace/database-engine",
            title: "Optimize Query Planner",
            state: .done,
            currentTool: nil,
            currentAction: "Done — click to jump",
            stateSince: now.addingTimeInterval(-10),
            usage: SessionUsage(model: "gpt-4o", tokens: TokenUsage(input: 112_000, output: 14_200), costUSD: 0.38),
            startedAt: now.addingTimeInterval(-300),
            lastEventAt: now.addingTimeInterval(-10)
        )

        notchController?.update([session1, session2])
        notchController?.update(pending: [])

        // Token tick up (no auto-advancing stage timer)
        tickCount = 0
        tokenTickerTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.tickCount += 1
                var s1 = session1
                s1.usage = SessionUsage(
                    model: "claude-sonnet-5",
                    tokens: TokenUsage(input: 42_100 + (self.tickCount * 1400), output: 8_400 + (self.tickCount * 300)),
                    costUSD: 0.16 + (Double(self.tickCount) * 0.015)
                )
                self.notchController?.update([s1, session2])
            }
        }
    }

    // MARK: - Stage 1: Tool Permission Card
    private func stageToolPermissionCard() {
        let req = DecisionRequest(
            id: "demo-perm-1",
            sessionKey: "demo-s1",
            kind: .toolPermission(
                tool: "Bash",
                preview: .command("npm run build && rm -rf ./dist/old-cache")
            ),
            receivedAt: Date()
        )
        notchController?.update(pending: [req])
    }

    // MARK: - Stage 2: Question Card
    private func stageQuestionCard() {
        let spec = QuestionSpec(
            question: "Which database migration strategy should we apply?",
            header: "Migration Plan",
            options: [
                QuestionOption(label: "Zero-downtime shadow table", description: "Safe for high throughput"),
                QuestionOption(label: "Direct ALTER TABLE inplace", description: "Faster execution")
            ],
            multiSelect: false
        )
        let req = DecisionRequest(
            id: "demo-q-1",
            sessionKey: "demo-s1",
            kind: .question(questions: [spec]),
            receivedAt: Date()
        )
        notchController?.update(pending: [req])
    }

    // MARK: - Stage 3: Plan Approval Card
    private func stagePlanApprovalCard() {
        let req = DecisionRequest(
            id: "demo-plan-1",
            sessionKey: "demo-s1",
            kind: .planApproval(text: """
            Proposed UI Refactoring Plan:
            1. Update NavigationBar.swift with glassmorphic background blur
            2. Migrate theme palette variables to Semantic Colors
            3. Run SwiftUI preview tests across dark/light modes
            """),
            receivedAt: Date()
        )
        notchController?.update(pending: [req])
    }

    // MARK: - Stage 4: Click-to-Jump Terminal Focus
    private func stageTerminalJump() {
        notchController?.update(pending: [])
        triggerTerminalJump("demo-s1")
    }

    // MARK: - Stage 5: Theme Carousel & Studio
    private func stageThemeAndSoundStudio() {
        notchController?.update(pending: [])
    }

    private func handleNotchDecision(_ request: DecisionRequest, decision: Decision) {
        soundPlayer?.play(.soundDone)
        lastSoundPlayed = "Glass (Decision Approved)"
        notchController?.update(pending: [])
        nextStage()
    }
}
