import SwiftUI

struct Theme: Identifiable {
    let id: String
    let name: String
    let palette: Palette
}

enum Themes {
    static let graphite = Theme(id: "graphite", name: "Graphite", palette: .graphite)

    static let midnight = Theme(id: "midnight", name: "Midnight", palette: Palette(
        surfaceTop: Color(hex: 0x050506), surfaceBottom: Color(hex: 0x000000),
        textPrimary: Color(hex: 0xF2F2F5), textSecondary: Color(hex: 0x8E8E96),
        working: Color(hex: 0x2E9BFF), done: Color(hex: 0x3BE06A), failed: Color(hex: 0xFF5A50),
        needsPermission: Color(hex: 0xFFB020), plan: Color(hex: 0xB79CFF), question: Color(hex: 0x66D0FF),
        needsInputDot: Color(hex: 0xFFDE38),
        agentClaude: Color(hex: 0xF0A085), agentCodex: Color(hex: 0x5FE0C0), agentGemini: Color(hex: 0x9CBBFF),
        innerBox: Color(hex: 0x000000), border: Color.white.opacity(0.14)))

    static let highContrast = Theme(id: "high-contrast", name: "High Contrast", palette: Palette(
        surfaceTop: Color(hex: 0x0A0A0C), surfaceBottom: Color(hex: 0x000000),
        textPrimary: Color(hex: 0xFFFFFF), textSecondary: Color(hex: 0xC7C7CE),
        working: Color(hex: 0x339CFF), done: Color(hex: 0x34E06A), failed: Color(hex: 0xFF4136),
        needsPermission: Color(hex: 0xFFB000), plan: Color(hex: 0xB899FF), question: Color(hex: 0x4EC8FF),
        needsInputDot: Color(hex: 0xFFE000),
        agentClaude: Color(hex: 0xFFA98C), agentCodex: Color(hex: 0x57E7C4), agentGemini: Color(hex: 0x9FC0FF),
        innerBox: Color(hex: 0x000000), border: Color.white.opacity(0.30)))

    static let warm = Theme(id: "warm", name: "Warm", palette: Palette(
        surfaceTop: Color(hex: 0x16110F), surfaceBottom: Color(hex: 0x0D0A09),
        textPrimary: Color(hex: 0xF1E8E2), textSecondary: Color(hex: 0xA89A92),
        working: Color(hex: 0x6FB0A6), done: Color(hex: 0x86C08A), failed: Color(hex: 0xE0685C),
        needsPermission: Color(hex: 0xE8A85E), plan: Color(hex: 0xB79CC9), question: Color(hex: 0x7FB8C9),
        needsInputDot: Color(hex: 0xE9C46A),
        agentClaude: Color(hex: 0xE39178), agentCodex: Color(hex: 0x9CC2A0), agentGemini: Color(hex: 0xA9B8D6)))

    static let nord = Theme(id: "nord", name: "Nord", palette: Palette(
        surfaceTop: Color(hex: 0x3B4252), surfaceBottom: Color(hex: 0x2E3440),
        textPrimary: Color(hex: 0xECEFF4), textSecondary: Color(hex: 0xA6ADBB),
        working: Color(hex: 0x81A1C1), done: Color(hex: 0xA3BE8C), failed: Color(hex: 0xBF616A),
        needsPermission: Color(hex: 0xD08770), plan: Color(hex: 0xB48EAD), question: Color(hex: 0x88C0D0),
        needsInputDot: Color(hex: 0xEBCB8B),
        agentClaude: Color(hex: 0xEBCB8B), agentCodex: Color(hex: 0x8FBCBB), agentGemini: Color(hex: 0x81A1C1),
        innerBox: Color(hex: 0x292E39), border: Color(hex: 0x4C566A), ended: Color(hex: 0x4C566A)))

    static let catppuccin = Theme(id: "catppuccin", name: "Catppuccin", palette: Palette(
        surfaceTop: Color(hex: 0x1E1E2E), surfaceBottom: Color(hex: 0x181825),
        textPrimary: Color(hex: 0xCDD6F4), textSecondary: Color(hex: 0xA6ADC8),
        working: Color(hex: 0x89B4FA), done: Color(hex: 0xA6E3A1), failed: Color(hex: 0xF38BA8),
        needsPermission: Color(hex: 0xFAB387), plan: Color(hex: 0xCBA6F7), question: Color(hex: 0x94E2D5),
        needsInputDot: Color(hex: 0xF9E2AF),
        agentClaude: Color(hex: 0xF5E0DC), agentCodex: Color(hex: 0x74C7EC), agentGemini: Color(hex: 0xB4BEFE),
        innerBox: Color(hex: 0x11111B), border: Color(hex: 0x313244), ended: Color(hex: 0x6C7086),
        onAccent: Color(hex: 0x0E0E11)))

    static let tokyoNight = Theme(id: "tokyo-night", name: "Tokyo Night", palette: Palette(
        surfaceTop: Color(hex: 0x1A1B26), surfaceBottom: Color(hex: 0x16161E),
        textPrimary: Color(hex: 0xC0CAF5), textSecondary: Color(hex: 0x9AA5CE),
        working: Color(hex: 0x7AA2F7), done: Color(hex: 0x9ECE6A), failed: Color(hex: 0xF7768E),
        needsPermission: Color(hex: 0xFF9E64), plan: Color(hex: 0xBB9AF7), question: Color(hex: 0x7DCFFF),
        needsInputDot: Color(hex: 0xE0AF68),
        agentClaude: Color(hex: 0xF7768E), agentCodex: Color(hex: 0x73DACA), agentGemini: Color(hex: 0x7AA2F7),
        innerBox: Color(hex: 0x101014), border: Color(hex: 0x292E42), ended: Color(hex: 0x565F89),
        onAccent: Color(hex: 0x0E0E11)))

    static let dune = Theme(id: "dune", name: "Dune", palette: Palette(
        surfaceTop: Color(hex: 0x14100C), surfaceBottom: Color(hex: 0x0B0906),
        textPrimary: Color(hex: 0xEDE0CF), textSecondary: Color(hex: 0xB8A488),
        working: Color(hex: 0x5AA0C4), done: Color(hex: 0xA3B565), failed: Color(hex: 0xC0392B),
        needsPermission: Color(hex: 0xE8873A), plan: Color(hex: 0x9B7BB0), question: Color(hex: 0x6FB2A6),
        needsInputDot: Color(hex: 0xE3B23C),
        agentClaude: Color(hex: 0xB5895F), agentCodex: Color(hex: 0x8FB56A), agentGemini: Color(hex: 0x6FA3C4),
        innerBox: Color(hex: 0x0A0705)))

    static let matrix = Theme(id: "matrix", name: "Matrix", palette: Palette(
        surfaceTop: Color(hex: 0x030503), surfaceBottom: Color(hex: 0x000000),
        textPrimary: Color(hex: 0xB9FFB9), textSecondary: Color(hex: 0x5FA85F),
        working: Color(hex: 0x39FF14), done: Color(hex: 0x00E676), failed: Color(hex: 0xFF3B30),
        needsPermission: Color(hex: 0xFFD400), plan: Color(hex: 0x7CFFB0), question: Color(hex: 0x00FFC8),
        needsInputDot: Color(hex: 0xEEFF41),
        agentClaude: Color(hex: 0x00E676), agentCodex: Color(hex: 0x39FF14), agentGemini: Color(hex: 0x7CFFB0),
        innerBox: Color(hex: 0x000000), border: Color(hex: 0x00FF41).opacity(0.22), ended: Color(hex: 0x2E7D32),
        onAccent: Color(hex: 0x0E0E11)))

    static let avengers = Theme(id: "avengers", name: "Avengers", palette: Palette(
        surfaceTop: Color(hex: 0x0E0B0B), surfaceBottom: Color(hex: 0x050303),
        textPrimary: Color(hex: 0xF5EFE6), textSecondary: Color(hex: 0xB9A98F),
        working: Color(hex: 0x3B82F6), done: Color(hex: 0x2FBF71), failed: Color(hex: 0xE23636),
        needsPermission: Color(hex: 0xE6A817), plan: Color(hex: 0x7C5CFF), question: Color(hex: 0x22B8CF),
        needsInputDot: Color(hex: 0xF5C518),
        agentClaude: Color(hex: 0xE6564B), agentCodex: Color(hex: 0x22B8CF), agentGemini: Color(hex: 0x3B82F6),
        innerBox: Color(hex: 0x080505)))

    static let all: [Theme] = [graphite, midnight, highContrast, warm, nord,
                               catppuccin, tokyoNight, dune, matrix, avengers]
    static let `default` = graphite
}
