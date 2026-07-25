import SwiftUI
import ClaudeNotchCore

@MainActor
final class NotchViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var pendingDecisions: [DecisionRequest] = []
    @Published var now: Date = Date()
    @Published var notice: String?
    @Published var palette: Palette = .graphite
    var onJump: ((Session) -> Void)?
    var onDecide: ((DecisionRequest, Decision) -> Void)?
    var onAnswerInTerminal: ((DecisionRequest) -> Void)?
}

extension SessionState {
    var glyph: String {
        switch self {
        case .needsPermission: return "🟠"
        case .needsInput: return "🟡"
        case .working: return "🔵"
        case .done: return "✅"
        case .failed: return "❌"
        case .ended: return "⚪️"
        }
    }
    var label: String {
        switch self {
        case .needsPermission: return "needs permission"
        case .needsInput: return "needs input"
        case .working: return "working"
        case .done: return "done"
        case .failed: return "failed"
        case .ended: return "ended"
        }
    }
}

extension SessionState {
    var shortLabel: String {
        switch self {
        case .needsPermission, .needsInput: return "waiting"
        case .working: return "working"
        case .done: return "done"
        case .failed: return "failed"
        case .ended: return "ended"
        }
    }
}

enum ModelName {
    private static let map: [String: String] = [
        "claude-opus-4-8": "Opus 4.8", "claude-opus-4-7": "Opus 4.7",
        "claude-sonnet-5": "Sonnet 5", "claude-haiku-4-5": "Haiku 4.5",
        "claude-fable-5": "Fable 5",
    ]
    static func friendly(_ raw: String) -> String {
        if let f = map[raw] { return f }
        if let hit = map.first(where: { raw.hasPrefix($0.key) }) { return hit.value }
        return raw.replacingOccurrences(of: "claude-", with: "")
    }
}

enum Format {
    static func duration(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        let (h, m, sec) = (s / 3600, (s % 3600) / 60, s % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }
    static func tokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fk", Double(n) / 1_000) }
        return "\(n)"
    }
    static func usage(_ u: SessionUsage) -> String {
        let t = tokens(u.tokens.total)
        guard let c = u.costUSD else { return t }
        return t + (c < 0.005 ? " · <$0.01" : String(format: " · $%.2f", c))
    }
}

struct NotchExpandedView: View {
    @ObservedObject var vm: NotchViewModel
    @Environment(\.palette) private var palette
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let req = vm.pendingDecisions.max(by: { $0.receivedAt < $1.receivedAt }) {
                DecisionCardView(
                    request: req,
                    session: vm.sessions.first { $0.key == req.sessionKey },
                    remaining: vm.pendingDecisions.count - 1,
                    onDecide: vm.onDecide,
                    onAnswerInTerminal: vm.onAnswerInTerminal)
            } else {
                sessionList
            }
            if let notice = vm.notice {
                Text(notice).font(.system(size: 11)).foregroundStyle(palette.failed)
                    .padding(.horizontal, 12).padding(.bottom, 10)
            }
        }
        .frame(width: NotchMetric.panelWidth)
        .environment(\.palette, vm.palette)
    }

    @ViewBuilder private var sessionList: some View {
        VStack(alignment: .leading, spacing: 6) {
            if vm.sessions.isEmpty {
                Text("No active Claude Code sessions").foregroundStyle(palette.textSecondary)
            } else {
                UsageHeader(sessions: vm.sessions)
                ForEach(vm.sessions) { s in
                    Button { vm.onJump?(s) } label: { SessionRow(session: s, now: vm.now) }
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
    }
}

struct SessionRow: View {
    let session: Session
    let now: Date
    @Environment(\.palette) private var palette

    /// State-aware activity text: a done session invites the click-to-jump; otherwise the live action.
    private var activityText: String? {
        switch session.state {
        case .done:   return "Done — click to jump"
        case .failed: return session.currentAction ?? session.currentTool ?? "Failed"
        default:      return session.currentAction ?? session.currentTool
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(palette.dot(for: session.state)).frame(width: 9, height: 9)
                .shadow(color: palette.dot(for: session.state).opacity(0.5), radius: 4)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.projectName).font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.textPrimary).lineLimit(1)
                    if let model = session.usage?.model {
                        Text(ModelName.friendly(model)).font(.system(size: 11)).foregroundStyle(palette.textSecondary)
                    }
                }
                if let activity = activityText {
                    ActivityLine(text: activity, accent: session.state.surfaceAccent)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(session.state.shortLabel) \(Format.duration(now.timeIntervalSince(session.stateSince)))")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(palette.dot(for: session.state))
                HStack(spacing: 5) {
                    AgentBadgeView(agentID: session.agentID)
                    if let term = session.terminal.appName, !term.isEmpty {
                        Badge(text: term.replacingOccurrences(of: ".app", with: ""))
                    }
                }
                if let usage = session.usage, usage.tokens.total > 0 {
                    Text(Format.usage(usage)).font(.system(size: 10.5)).foregroundStyle(palette.textSecondary)
                }
            }
        }
        .contentShape(Rectangle())   // whole row is the click/hit target
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
    }
}

/// Honest usage summary across active sessions: total tokens + cost we already track.
/// NOT a calendar-day total and NOT a rate-limit readout — labeled for exactly what it is.
struct UsageHeader: View {
    let sessions: [Session]
    @Environment(\.palette) private var palette

    var body: some View {
        let t = Self.totals(sessions)
        if t.tokens > 0 {
            HStack(spacing: 8) {
                Text("✦").font(.system(size: 12)).foregroundStyle(palette.spark)
                Text("\(t.count) active session\(t.count == 1 ? "" : "s")")
                    .font(.system(size: 11)).foregroundStyle(palette.textSecondary)
                Spacer(minLength: 8)
                Text(Self.readout(t)).font(.system(size: 11)).foregroundStyle(palette.textSecondary)
            }
            .padding(.bottom, 4)
        }
    }

    static func totals(_ sessions: [Session]) -> (count: Int, tokens: Int, cost: Double?) {
        let used = sessions.filter { ($0.usage?.tokens.total ?? 0) > 0 }
        let tokens = used.reduce(0) { $0 + ($1.usage?.tokens.total ?? 0) }
        let costs = used.compactMap { $0.usage?.costUSD }
        return (used.count, tokens, costs.isEmpty ? nil : costs.reduce(0, +))
    }

    static func readout(_ t: (count: Int, tokens: Int, cost: Double?)) -> String {
        let tok = Format.tokens(t.tokens) + " tok"
        guard let c = t.cost, c > 0 else { return tok }
        return tok + " · " + (c < 0.005 ? "<$0.01" : String(format: "$%.2f", c))
    }
}

struct NotchCompactView: View {
    @ObservedObject var vm: NotchViewModel
    var body: some View {
        let waiting = vm.sessions.filter { $0.state == .needsInput || $0.state == .needsPermission }.count
        let working = vm.sessions.filter { $0.state == .working }.count
        let done = vm.sessions.filter { $0.state == .done }.count
        let failed = vm.sessions.filter { $0.state == .failed }.count
        HStack(spacing: 9) {
            if waiting > 0 { CountDot(accent: .permission, count: waiting) }
            if working > 0 { CountDot(accent: .working,    count: working) }
            if done > 0    { CountDot(accent: .done,       count: done) }
            if failed > 0  { CountDot(accent: .failed,     count: failed) }
        }
        .padding(.horizontal, 8)
        .environment(\.palette, vm.palette)
    }
}

/// A crisp colored dot + count for the compact pill (replaces the emoji glyphs).
struct CountDot: View {
    let accent: Accent
    let count: Int
    @Environment(\.palette) private var palette
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(palette.accent(accent)).frame(width: 7, height: 7)
                .shadow(color: palette.accent(accent).opacity(0.6), radius: 3)
            Text("\(count)").font(.system(size: 12, weight: .semibold)).foregroundStyle(palette.textPrimary)
        }
    }
}

struct DecisionCardView: View {
    let request: DecisionRequest
    let session: Session?
    let remaining: Int
    var onDecide: ((DecisionRequest, Decision) -> Void)?
    var onAnswerInTerminal: ((DecisionRequest) -> Void)?
    @Environment(\.palette) private var palette

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                AccentStrip(title: stripTitle, accent: request.kind.accent)
                SessionContextStrip(session: session)
                bodyContent
                footer
            }
        }
    }

    private var stripTitle: String {
        switch request.kind {
        case let .toolPermission(tool, _): return "Permission · \(tool)"
        case .question:                    return "\(AgentBadge.name(session?.agentID ?? "claude")) asks"
        case .planApproval:                return "Plan ready"
        }
    }

    @ViewBuilder private var bodyContent: some View {
        switch request.kind {
        case let .toolPermission(_, preview):
            previewBody(preview)
            VStack(spacing: 8) {
                HStack(spacing: 9) {
                    ActionButton(title: "Deny", style: .ghost) {
                        onDecide?(request, .deny(reason: "Denied from notch"))
                    }
                    ActionButton(title: "Allow", style: .primary(.permission)) {
                        onDecide?(request, .allow(scope: .once))
                    }
                }
                ActionButton(title: "Allow for this session", style: .ghost) {
                    onDecide?(request, .allow(scope: .session))
                }
            }
        case let .planApproval(text):
            planBody(text)
            HStack(spacing: 9) {
                ActionButton(title: "Request changes", style: .ghost) {
                    onDecide?(request, .deny(reason: "Requested changes from notch"))
                }
                ActionButton(title: "Approve plan", style: .primary(.plan)) {
                    onDecide?(request, .allow(scope: .once))
                }
            }
        case let .question(questions):
            questionBody(questions)
        }
    }

    @ViewBuilder private var footer: some View {
        HStack {
            ActionButton(title: "Answer in terminal", style: .ghost, fill: false) {
                onAnswerInTerminal?(request)
            }
            Spacer()
            if remaining > 0 {
                Text("\(remaining) more waiting").font(.caption).foregroundStyle(palette.textSecondary)
            }
        }
    }

    @ViewBuilder private func questionBody(_ questions: [QuestionSpec]) -> some View {
        if let q = questions.first, questions.count == 1, !q.multiSelect {
            if let header = q.header, !header.isEmpty {
                Text(header).font(.caption).foregroundStyle(palette.textSecondary)
            }
            Text(q.question).font(.system(size: 14, weight: .medium)).foregroundStyle(palette.textPrimary)
            VStack(spacing: 8) {
                ForEach(Array(q.options.enumerated()), id: \.offset) { idx, opt in
                    OptionRow(index: idx + 1, label: opt.label, description: opt.description, accent: .question) {
                        onDecide?(request, .answer(answers: [q.question: opt.label]))
                    }
                }
            }
        } else {
            Text("Answer this one in the terminal.").font(.caption).foregroundStyle(palette.textSecondary)
        }
    }

    @ViewBuilder private func planBody(_ text: String) -> some View {
        ScrollView {
            Text(text).font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 150)
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [.clear, palette.innerBox], startPoint: .top, endPoint: .bottom)
                .frame(height: 22)
                .allowsHitTesting(false)
        }
        .padding(8)
        .background(palette.innerBox, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(palette.plan.opacity(0.2), lineWidth: 1))
    }

    /// A compact +added / -removed summary for a diff preview.
    private func diffStat(_ lines: [DiffLine]) -> some View {
        let added = lines.filter { $0.kind == .added }.count
        let removed = lines.filter { $0.kind == .removed }.count
        return HStack(spacing: 8) {
            if added > 0 { Text("+\(added)").foregroundStyle(palette.diffAdd) }
            if removed > 0 { Text("-\(removed)").foregroundStyle(palette.diffRemove) }
        }
        .font(.system(.caption2, design: .monospaced))
        .padding(.top, 3)
    }

    @ViewBuilder private func previewBody(_ preview: ToolPreview) -> some View {
        ScrollView {
            Group {
                switch preview {
                case let .diff(file, lines):
                    VStack(alignment: .leading, spacing: 1) {
                        Text(file).font(.system(.caption2, design: .monospaced)).foregroundStyle(palette.textSecondary)
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text((line.kind == .added ? "+ " : line.kind == .removed ? "- " : "  ") + line.text)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(line.kind == .added ? palette.diffAdd : line.kind == .removed ? palette.diffRemove : palette.textPrimary)
                        }
                        diffStat(lines)
                    }
                case let .command(cmd):
                    Text(cmd).font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                case let .raw(s):
                    Text(s).font(.system(.caption, design: .monospaced)).foregroundStyle(palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 150)
        .padding(8)
        .background(palette.innerBox, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(palette.border, lineWidth: 1))
    }
}
