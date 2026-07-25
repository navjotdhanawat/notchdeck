import SwiftUI
import NotchDeckCore

/// Consistent card shell: a solid dark surface (a subtle top→bottom gradient from the
/// active palette) with a hairline NEUTRAL border. Deliberately NOT `.regularMaterial` —
/// over the notch's dark panel the system material renders as a washed-out gray veil that
/// kills text/accent contrast.
struct CardContainer<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.palette) private var palette

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(NotchMetric.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: NotchMetric.corner)
                    .fill(LinearGradient(colors: [palette.surfaceTop, palette.surfaceBottom],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: NotchMetric.corner)
                    .strokeBorder(palette.border, lineWidth: NotchMetric.hairline)
            )
    }
}

/// The colored top strip of a card: a glowing dot + accent-colored title.
struct AccentStrip: View {
    let title: String
    let accent: Accent
    @Environment(\.palette) private var palette
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(palette.accent(accent)).frame(width: 8, height: 8)
                .shadow(color: palette.accent(accent).opacity(0.6), radius: 4)
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.accent(accent))
            Spacer(minLength: 0)
        }
    }
}

/// A small pill: agent badges pass a tint; terminal/model badges use the neutral default.
struct Badge: View {
    let text: String
    var tint: Color? = nil
    @Environment(\.palette) private var palette
    var body: some View {
        let c = tint ?? palette.textSecondary
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .foregroundStyle(c)
            .background(c.opacity(0.16), in: RoundedRectangle(cornerRadius: NotchMetric.badgeCorner))
            .overlay(RoundedRectangle(cornerRadius: NotchMetric.badgeCorner).strokeBorder(c.opacity(0.28), lineWidth: 1))
    }
}

/// Agent badge with per-agent tint, resolved from `Session.agentID`.
struct AgentBadgeView: View {
    let agentID: String
    @Environment(\.palette) private var palette
    var body: some View {
        Badge(text: AgentBadge.name(agentID), tint: palette.agentTint(agentID))
    }
}

/// project · [agent] · [terminal] context for a decision card. Degrades to empty when nil.
struct SessionContextStrip: View {
    let session: Session?
    @Environment(\.palette) private var palette
    var body: some View {
        if let s = session {
            HStack(spacing: 7) {
                Text(s.projectName).font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(palette.textSecondary).lineLimit(1)
                AgentBadgeView(agentID: s.agentID)
                if let term = s.terminal.appName, !term.isEmpty {
                    Badge(text: term.replacingOccurrences(of: ".app", with: ""))
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// Numbered index chip (visual order marker — NOT a keyboard shortcut).
struct IndexChip: View {
    let n: Int
    var accent: Accent = .question
    @Environment(\.palette) private var palette
    var body: some View {
        Text("\(n)")
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .frame(width: 22, height: 22)
            .foregroundStyle(palette.accent(accent))
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(palette.accent(accent).opacity(0.3), lineWidth: 1))
    }
}

/// A pressable AskUserQuestion option: index chip + label + optional description.
struct OptionRow: View {
    let index: Int
    let label: String
    let description: String?
    let accent: Accent
    let action: () -> Void
    @Environment(\.palette) private var palette
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 11) {
                IndexChip(n: index, accent: accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(palette.textPrimary)
                    if let d = description, !d.isEmpty {
                        Text(d).font(.system(size: 11)).foregroundStyle(palette.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8).padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.softFill(accent).opacity(hovering ? 1.4 : 1.0), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(palette.accent(accent).opacity(hovering ? 0.5 : 0.22), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

enum ActionButtonStyle { case ghost; case primary(Accent) }

/// A card action button. `fill` = stretch to full width (default) vs hug content (footer use).
struct ActionButton: View {
    let title: String
    let style: ActionButtonStyle
    var fill: Bool = true
    let action: () -> Void
    @Environment(\.palette) private var palette
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: fill ? .infinity : nil)
                .padding(.vertical, 9).padding(.horizontal, 12)
                .foregroundStyle(foregroundColor)
                .background(background, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
    private var foregroundColor: Color {
        switch style {
        case .ghost:   return palette.textPrimary
        case .primary: return palette.onAccent
        }
    }
    private var background: Color {
        switch style {
        case .ghost: return Color.white.opacity(hovering ? 0.15 : 0.09)
        case .primary(let a): return palette.accent(a).opacity(hovering ? 1.0 : 0.85)
        }
    }
    private var border: Color {
        switch style {
        case .ghost: return Color.white.opacity(0.10)
        case .primary(let a): return palette.accent(a).opacity(0.9)
        }
    }
}

/// One-line "what it's doing now", colored by the session's surface accent.
struct ActivityLine: View {
    let text: String
    let accent: Accent
    @Environment(\.palette) private var palette
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(accent == .neutral ? palette.textSecondary : palette.accent(accent))
            .lineLimit(1)
    }
}
