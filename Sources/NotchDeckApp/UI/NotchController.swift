import SwiftUI
import DynamicNotchKit
import NotchDeckCore
import Combine

@MainActor
public final class NotchController {
    private let vm = NotchViewModel()
    private var notch: DynamicNotch<AnyView, AnyView, AnyView>?
    public var onJump: ((Session) -> Void)? {
        didSet { vm.onJump = onJump }
    }
    public var onDecide: ((DecisionRequest, Decision) -> Void)? {
        didSet { vm.onDecide = onDecide }
    }
    public var onAnswerInTerminal: ((DecisionRequest) -> Void)? {
        didSet { vm.onAnswerInTerminal = onAnswerInTerminal }
    }

    public init() {
        let vm = self.vm
        // `hoverBehavior` defaults to `.all`, which includes `.hapticFeedback`: DynamicNotchKit
        // fires an NSHapticFeedbackManager pulse on every hover-enter. On a Force Touch trackpad
        // that pulse drives the same actuator as a physical click, so it feels like the trackpad
        // clicking by itself when the cursor merely rests on the notch. Drop it; keep only the
        // visible/shadow cues. (Hover-to-expand is unaffected — `$isHovering` still publishes.)
        notch = DynamicNotch(
            hoverBehavior: [.keepVisible, .increaseShadow],
            expanded: { AnyView(NotchExpandedView(vm: vm)) },
            compactLeading: { AnyView(NotchCompactView(vm: vm)) },
            compactTrailing: { AnyView(EmptyView()) }
        )

        // DynamicNotchKit's hover only enlarges the compact content — it does NOT reveal the
        // expanded view. Bridge its isHovering into our pump so hover flips us to .expanded.
        hoverCancellable = notch?.$isHovering
            .removeDuplicates()
            .sink { [weak self] hovering in
                Task { @MainActor in self?.hoverChanged(hovering) }
            }
    }

    /// Serial presentation pump state. Coalesces rapid `update(_:)` calls so the notch's final
    /// presentation always matches the most recent update and show/hide/expand animations never overlap
    /// (previously each call spawned its own detached Task, which could race and leave the notch
    /// stuck visible or flickering under bursty updates).
    private enum Presentation { case hidden, compact, expanded }
    private var desiredPresentation: Presentation = .hidden
    private var isPumping = false
    private var clock: Timer?
    private var noticeTimer: Timer?
    private var isHovering = false
    private var hoverEnterTimer: Timer?
    private var hoverExitTimer: Timer?
    private var hoverCancellable: AnyCancellable?
    private let hoverEnterDelay: TimeInterval = 0.30
    private let hoverExitGrace: TimeInterval = 0.25

    /// Update the rendered sessions and show/hide the notch based on whether anything is active.
    public func update(_ sessions: [Session]) {
        vm.sessions = sessions
        desiredPresentation = presentation(pending: vm.pendingDecisions, sessions: sessions)
        pump()
    }

    /// Update pending decisions, auto-expand if non-empty, and pump visibility.
    public func update(pending: [DecisionRequest]) {
        vm.pendingDecisions = pending
        desiredPresentation = presentation(pending: pending, sessions: vm.sessions)
        pump()
    }

    /// Apply a theme palette; the notch recolors live via the injected environment.
    /// Internal (not `public`) because `Palette` is a module-internal type and the sole
    /// caller — `AppCoordinator` — lives in this same module.
    func setPalette(_ palette: Palette) { vm.palette = palette }

    private func presentation(pending: [DecisionRequest], sessions: [Session]) -> Presentation {
        if !pending.isEmpty { return .expanded }
        if vm.notice != nil { return .expanded }   // keep the notch open so a transient notice (failed jump / TCC hint) stays readable
        if !sessions.isEmpty { return isHovering ? .expanded : .compact }
        return .hidden
    }

    /// Debounce raw hover: enter after a short delay (avoid accidental menu-bar triggers),
    /// leave after a grace (absorb the blip when the panel grows under the cursor).
    private func hoverChanged(_ hovering: Bool) {
        if hovering {
            hoverExitTimer?.invalidate(); hoverExitTimer = nil
            guard hoverEnterTimer == nil, !isHovering else { return }
            hoverEnterTimer = Timer.scheduledTimer(withTimeInterval: hoverEnterDelay, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.applyHover(true) }
            }
        } else {
            hoverEnterTimer?.invalidate(); hoverEnterTimer = nil
            guard hoverExitTimer == nil, isHovering else { return }
            hoverExitTimer = Timer.scheduledTimer(withTimeInterval: hoverExitGrace, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.applyHover(false) }
            }
        }
    }

    private func applyHover(_ value: Bool) {
        hoverEnterTimer = nil; hoverExitTimer = nil
        guard isHovering != value else { return }
        isHovering = value
        desiredPresentation = presentation(pending: vm.pendingDecisions, sessions: vm.sessions)
        pump()
    }

    /// Coalesces show/hide/expand updates to prevent animation overlap and ensure final presentation
    /// matches the most recent `desiredPresentation` state.
    private func pump() {
        guard !isPumping else { return } // an active pump will drain to the latest desired state
        isPumping = true
        Task { [weak self] in
            guard let self else { return }
            var applied: Presentation?
            while applied != self.desiredPresentation {
                let target = self.desiredPresentation
                switch target {
                case .hidden:   await self.notch?.hide();    self.stopClock()
                case .compact:  await self.notch?.compact(); self.startClock()
                case .expanded: await self.notch?.expand();  self.startClock()
                }
                applied = target
            }
            self.isPumping = false
        }
    }

    // Session rows show live durations; the clock runs whenever the notch is visible so the times
    // tick in both compact and (hover-)expanded states.
    private func startClock() {
        guard clock == nil else { return }
        clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.vm.now = Date() }
        }
    }
    private func stopClock() { clock?.invalidate(); clock = nil }

    /// Show a transient notice in the expanded view for a few seconds (e.g. a failed jump).
    public func showNotice(_ text: String) {
        vm.notice = text
        desiredPresentation = presentation(pending: vm.pendingDecisions, sessions: vm.sessions)
        pump()
        noticeTimer?.invalidate()
        noticeTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.vm.notice = nil
                self.desiredPresentation = self.presentation(pending: self.vm.pendingDecisions, sessions: self.vm.sessions)
                self.pump()
            }
        }
    }
}
