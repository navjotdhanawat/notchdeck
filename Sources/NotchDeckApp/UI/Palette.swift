import SwiftUI
import NotchDeckCore

extension Color {
    /// 0xRRGGBB → opaque sRGB Color. Keeps palette definitions readable.
    init(hex: UInt) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// The single source of truth for every color the notch UI draws. A "theme" is a `Palette`.
/// Derivable fields (innerBox, border, ended, agentFallback, diffAdd/Remove, spark) default
/// so each theme only specifies its core hues.
struct Palette {
    let surfaceTop: Color, surfaceBottom: Color, innerBox: Color, border: Color
    let textPrimary: Color, textSecondary: Color, onAccent: Color
    let working: Color, done: Color, failed: Color
    let needsPermission: Color, plan: Color, question: Color, ended: Color
    let needsInputDot: Color
    let agentClaude: Color, agentCodex: Color, agentGemini: Color, agentFallback: Color
    let diffAdd: Color, diffRemove: Color, spark: Color

    init(surfaceTop: Color, surfaceBottom: Color, textPrimary: Color, textSecondary: Color,
         working: Color, done: Color, failed: Color, needsPermission: Color,
         plan: Color, question: Color, needsInputDot: Color,
         agentClaude: Color, agentCodex: Color, agentGemini: Color,
         innerBox: Color? = nil, border: Color? = nil, ended: Color? = nil,
         agentFallback: Color? = nil, diffAdd: Color? = nil, diffRemove: Color? = nil,
         spark: Color? = nil, onAccent: Color? = nil) {
        self.surfaceTop = surfaceTop
        self.surfaceBottom = surfaceBottom
        self.innerBox = innerBox ?? Color.black.opacity(0.28)
        self.border = border ?? Color.white.opacity(0.12)
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.onAccent = onAccent ?? .white
        self.working = working; self.done = done; self.failed = failed
        self.needsPermission = needsPermission; self.plan = plan; self.question = question
        self.ended = ended ?? textSecondary.opacity(0.75)
        self.needsInputDot = needsInputDot
        self.agentClaude = agentClaude; self.agentCodex = agentCodex; self.agentGemini = agentGemini
        self.agentFallback = agentFallback ?? textSecondary
        self.diffAdd = diffAdd ?? done
        self.diffRemove = diffRemove ?? failed
        self.spark = spark ?? needsInputDot
    }

    func accent(_ a: Accent) -> Color {
        switch a {
        case .permission: return needsPermission
        case .question:   return question
        case .plan:       return plan
        case .working:    return working
        case .done:       return done
        case .failed:     return failed
        case .neutral:    return textSecondary
        }
    }
    func softFill(_ a: Accent) -> Color { accent(a).opacity(0.14) }
    func dot(for s: SessionState) -> Color {
        switch s {
        case .needsPermission: return needsPermission
        case .needsInput:      return needsInputDot
        case .working:         return working
        case .done:            return done
        case .failed:          return failed
        case .ended:           return ended
        }
    }
    func agentTint(_ id: String) -> Color {
        switch id {
        case "claude": return agentClaude
        case "codex":  return agentCodex
        case "gemini": return agentGemini
        default:       return agentFallback
        }
    }

    /// Graphite — the default theme (the refined current look).
    static let graphite = Palette(
        surfaceTop: Color(hex: 0x131316), surfaceBottom: Color(hex: 0x0C0C0E),
        textPrimary: Color(hex: 0xECEAE4), textSecondary: Color(hex: 0x8B8B93),
        working: Color(hex: 0x0A84FF), done: Color(hex: 0x30D158), failed: Color(hex: 0xFF453A),
        needsPermission: Color(hex: 0xFF9F0A), plan: Color(hex: 0xA78BFA), question: Color(hex: 0x5AC8FA),
        needsInputDot: Color(hex: 0xFFD60A),
        agentClaude: Color(hex: 0xE39178), agentCodex: Color(hex: 0x5FD0B0), agentGemini: Color(hex: 0x8FB0F9))
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = .graphite
}
extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
