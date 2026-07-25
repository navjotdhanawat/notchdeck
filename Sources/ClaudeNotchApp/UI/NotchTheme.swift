import SwiftUI
import ClaudeNotchCore

/// Semantic accent for a notch surface — the single source of truth for the
/// accent-per-state system. Replaces scattered `.orange`/`.purple` literals.
enum Accent {
    case permission, question, plan, working, done, failed, neutral
}

/// Shared spacing/sizing so every surface reads as one system.
enum NotchMetric {
    static let corner: CGFloat = 14
    static let cardPadding: CGFloat = 12
    static let hairline: CGFloat = 1
    static let badgeCorner: CGFloat = 6
    /// Expanded panel width — drives both the decision card and the glance list so the
    /// notch never resizes between the two. Wide enough that dense content (permission
    /// diffs, plan text, multi-line option descriptions) doesn't wrap into a tall column.
    static let panelWidth: CGFloat = 440
}

/// Friendly display name for an agent badge, keyed by `Session.agentID`.
/// Mirrors the `ModelName` mapping precedent; keeps the view layer free of Core agent types.
/// The tint comes from the active `Palette`.
enum AgentBadge {
    static func name(_ id: String) -> String {
        switch id {
        case "claude": return "Claude"
        case "codex":  return "Codex"
        case "gemini": return "Gemini"
        default:       return id.isEmpty ? "agent" : id.capitalized
        }
    }
}

extension DecisionKind {
    /// The card accent for this decision kind.
    var accent: Accent {
        switch self {
        case .toolPermission: return .permission
        case .question:       return .question
        case .planApproval:   return .plan
        }
    }
}

extension SessionState {
    /// Surface accent for cards/activity lines. Note: this is intentionally separate
    /// from the status dot — needsInput's surface is teal, but its dot stays yellow
    /// (see `Palette.dot(for:)`).
    var surfaceAccent: Accent {
        switch self {
        case .needsPermission: return .permission
        case .needsInput:      return .question
        case .working:         return .working
        case .done:            return .done
        case .failed:          return .failed
        case .ended:           return .neutral
        }
    }
}
