import AppKit
import SwiftUI
import NotchDeckCore

public struct MockTerminalLine: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public let timestamp: String
    public let prompt: String
    public let text: String
    public let type: LineType

    public enum LineType: Sendable, Equatable {
        case input, output, tool, success, error, system
    }

    public init(timestamp: String, prompt: String, text: String, type: LineType) {
        self.timestamp = timestamp
        self.prompt = prompt
        self.text = text
        self.type = type
    }
}

@MainActor
final class DemoBackdropWindow: NSWindow {
    private var onExit: (() -> Void)?
    private var eventMonitor: Any?

    init(engine: LiveNotchDemoEngine, onExit: @escaping () -> Void) {
        self.onExit = onExit

        guard let screen = NSScreen.main else {
            super.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
            return
        }

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)))
        self.backgroundColor = .clear
        self.isOpaque = true
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let hostingView = NSHostingView(rootView: DemoBackdropView(engine: engine, onExit: onExit))
        self.contentView = hostingView
    }

    func show() {
        NSApp.presentationOptions = [.hideDock]
        self.makeKeyAndOrderFront(nil)

        // Global Esc key listener
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                self?.onExit?()
                return nil
            }
            return event
        }
    }

    func closeWindow() {
        NSApp.presentationOptions = []
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        self.orderOut(nil)
    }
}

struct DemoBackdropView: View {
    @ObservedObject var engine: LiveNotchDemoEngine
    let onExit: () -> Void

    var body: some View {
        ZStack {
            // 1. Opaque macOS Sonoma Desktop Wallpaper Background (Isolates demo completely)
            LinearGradient(
                colors: [
                    Color(hex: 0x080912),
                    Color(hex: 0x111628),
                    Color(hex: 0x1A1128),
                    Color(hex: 0x06070E)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 2. Simulated Lower Terminal Windows on Desktop
                HStack(spacing: 20) {
                    ForEach(engine.terminalWindows) { termWin in
                        SimulatedTerminalWindowView(
                            termWin: termWin,
                            isFocused: engine.activeFocusSessionKey == termWin.sessionKey,
                            isJumpEffect: engine.jumpFocusEffect && engine.activeFocusSessionKey == termWin.sessionKey
                        )
                        .onTapGesture {
                            engine.triggerTerminalJump(termWin.sessionKey)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)

                // 3. Theme Dock Bar (Visible during Stage 5 Theme Studio)
                if engine.currentStepIndex == 5 {
                    themeStudioDock
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // 4. Glassmorphic Floating Guided Control HUD (Positioned at bottom center, clear of notch)
                floatingGuidedHUDBar
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Theme Studio Dock Bar
    private var themeStudioDock: some View {
        HStack(spacing: 10) {
            Text("THEMES:")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(Color.white.opacity(0.5))

            ForEach(Themes.all) { theme in
                Button {
                    engine.selectTheme(theme.id)
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(theme.palette.working).frame(width: 8, height: 8)
                        Text(theme.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        theme.palette.surfaceTop,
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(engine.activeThemeID == theme.id ? Color.cyan : Color.white.opacity(0.15), lineWidth: engine.activeThemeID == theme.id ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
        )
    }

    // MARK: - Floating Glassmorphic Guided Control HUD
    private var floatingGuidedHUDBar: some View {
        VStack(spacing: 10) {
            if let step = engine.currentStep {
                HStack(alignment: .center, spacing: 16) {
                    // Left: Step Counter Badge
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("STEP \(step.id + 1) OF \(LiveNotchDemoEngine.steps.count)")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(Color.cyan)
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.4))
                            Text(step.badgeText)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                        Text(step.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white)
                    }

                    Divider()
                        .frame(height: 28)
                        .background(Color.white.opacity(0.15))

                    // Center: Step Subtitle & Sound Indicator
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.subtitle)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .lineLimit(2)
                            .frame(maxWidth: 420, alignment: .leading)

                        if let sound = engine.lastSoundPlayed {
                            HStack(spacing: 4) {
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.cyan)
                                Text("Audio chime: \(sound)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.cyan)
                            }
                            .transition(.opacity)
                        }
                    }

                    Spacer(minLength: 12)

                    // Right: Play/Pause, Prev, Next, Exit
                    HStack(spacing: 10) {
                        Button {
                            engine.prevStage()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.white)
                                .padding(8)
                                .background(Color.white.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(step.id == 0)

                        Button {
                            engine.togglePause()
                        } label: {
                            Image(systemName: engine.isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.white)
                                .padding(8)
                                .background(Color.white.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            engine.nextStage()
                        } label: {
                            HStack(spacing: 4) {
                                Text(step.id == LiveNotchDemoEngine.steps.count - 1 ? "Finish" : "Next")
                                    .font(.system(size: 12, weight: .bold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.cyan, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            onExit()
                        } label: {
                            Text("Esc")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.black.opacity(0.75))
                        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                        .shadow(color: .black.opacity(0.6), radius: 20, y: 10)
                )
                .frame(maxWidth: 880)
            }
        }
    }
}

// MARK: - Simulated Lower Terminal Window Component
struct SimulatedTerminalWindowView: View {
    let termWin: DemoTerminalWindow
    let isFocused: Bool
    let isJumpEffect: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Window Header Bar
            HStack(spacing: 8) {
                Circle().fill(Color.red.opacity(0.7)).frame(width: 10, height: 10)
                Circle().fill(Color.yellow.opacity(0.7)).frame(width: 10, height: 10)
                Circle().fill(Color.green.opacity(0.7)).frame(width: 10, height: 10)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.6))
                    Text("\(termWin.appName) — \(termWin.projectName)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))

            // Window Content Log
            VStack(alignment: .leading, spacing: 5) {
                ForEach(termWin.logs) { line in
                    HStack(alignment: .top, spacing: 6) {
                        Text(line.timestamp)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.35))
                        Text(line.prompt)
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.cyan)
                        Text(line.text)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(lineColor(line.type))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(Color(hex: 0x06070B))
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isJumpEffect ? Color.cyan : (isFocused ? Color.cyan.opacity(0.6) : Color.white.opacity(0.12)),
                    lineWidth: isJumpEffect ? 3 : (isFocused ? 2 : 1)
                )
        )
        .shadow(color: isJumpEffect ? Color.cyan.opacity(0.5) : Color.black.opacity(0.4), radius: isJumpEffect ? 16 : 8)
        .scaleEffect(isJumpEffect ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isJumpEffect)
    }

    private func lineColor(_ type: MockTerminalLine.LineType) -> Color {
        switch type {
        case .input:   return Color.white
        case .output:  return Color(hex: 0xC0CAF5)
        case .tool:    return Color(hex: 0xFFB020)
        case .success: return Color(hex: 0x3BE06A)
        case .error:   return Color(hex: 0xFF5A50)
        case .system:  return Color(hex: 0x9AA5CE)
        }
    }
}
