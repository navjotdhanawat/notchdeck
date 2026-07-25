# ClaudeNotch Theme System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate every UI color into one `Palette` (single source of truth, fixing inconsistency + the amber/terracotta collision) and ship 10 switchable, persisted built-in themes selectable from the menu-bar dropdown.

**Architecture:** `Accent` becomes a color-free semantic key; a `Palette` value type resolves all colors; a `Theme` wraps a `Palette`; a `ThemeStore` (`ObservableObject`, UserDefaults-persisted) holds the list + current; the palette reaches views via `@Environment(\.palette)`, bridged through `NotchViewModel.palette` (`@Published`) so switching recolors live; a **Theme ▸** submenu in the AppKit status-bar menu drives selection.

**Tech Stack:** Swift 5.9+, SwiftUI + AppKit, DynamicNotchKit, SwiftPM. All new types live in the **App module** (`ClaudeNotchApp`) — they use SwiftUI `Color`; `ClaudeNotchCore` stays Foundation-only.

## Global Constraints

- **App-module only.** No changes to `ClaudeNotchCore`, transport, hooks, decision logic, jump, or agent/terminal seams. Behavior stays identical; the decision wire is untouched.
- **No new test cases** (repo + project policy; the App module has no tests). Per-task verification = `swift build` **0 warnings** + `swift test` still **78/78**. Update a test only if a symbol it references is renamed (none are).
- **Single source of truth:** after this work, `grep -nE '\.(blue|green|red|orange|yellow|purple)\b' Sources/ClaudeNotchApp/UI/NotchViews.swift Sources/ClaudeNotchApp/UI/NotchComponents.swift` must return **nothing** — all colors come from the palette. Raw literals live only in `Palette.swift`/`Themes.swift`.
- **Locked decisions:** neutral card border from `palette.border` (accent carried only by the strip dot+title); agent tints are themeable (`palette.agentTint`); `needsInput` keeps a distinct dot via `palette.needsInputDot`; live recolor via `@Environment(\.palette)` bridged by `NotchViewModel.palette`; persistence key `notch.themeID` in `UserDefaults.standard`; unknown/missing id → Graphite.
- **10 themes:** Graphite (default) · Midnight · High-contrast · Warm · Nord · Catppuccin · Tokyo Night · Dune · Matrix · Avengers.
- **Commit policy:** local git only, conventional commits, **no JIRA prefix**; every message ends with the trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Branch:** `feat/claudenotch-themes` (already created; spec committed there). Build/test from repo root `/Users/navjotdhanawat/Workspace/claude-notch`.

## File Structure

- **New** `Sources/ClaudeNotchApp/UI/Palette.swift` — `Color(hex:)`, `Palette` struct (fields + defaulted init + resolvers), `EnvironmentValues.palette`, `Palette.graphite`.
- **New** `Sources/ClaudeNotchApp/UI/Themes.swift` — `Theme` struct + the 10 `Theme` instances + `Themes.all` / `Themes.default`.
- **New** `Sources/ClaudeNotchApp/UI/ThemeStore.swift` — `ThemeStore: ObservableObject` + UserDefaults persistence.
- **Edit** `NotchTheme.swift` — strip colors from `Accent` (keep enum + `NotchMetric`); make `AgentBadge` name-only.
- **Edit** `NotchComponents.swift` — every component reads `@Environment(\.palette)`; resolve via palette; `CardContainer` uses palette surfaces + neutral border.
- **Edit** `NotchViews.swift` — `NotchViewModel.palette`; roots inject `.environment(\.palette, vm.palette)`; dots/pill/diff/spark/notice via palette.
- **Edit** `AppCoordinator.swift` — own `ThemeStore`, bridge to `vm.palette`, add **Theme ▸** submenu + `selectTheme(_:)`.

Ordering keeps every task build-clean: new types first (1–2), migrate readers (3–4) while the old `Accent` colors still exist, then remove the dead old API (5), then wire the store + menu (6).

---

### Task 1: `Palette` foundation + Environment + Graphite default + VM field

**Files:**
- Create: `Sources/ClaudeNotchApp/UI/Palette.swift`
- Modify: `Sources/ClaudeNotchApp/UI/NotchViews.swift` (add `palette` to `NotchViewModel` only)

**Interfaces produced:**
- `extension Color { init(hex: UInt) }`
- `struct Palette` with fields + `init(...)` (core args required, derivable ones defaulted) + `func accent(_ Accent) -> Color`, `func softFill(_ Accent) -> Color`, `func dot(for SessionState) -> Color`, `func agentTint(_ String) -> Color`.
- `static let Palette.graphite`
- `EnvironmentValues.palette` (default `.graphite`)
- `NotchViewModel.palette: Palette` (`@Published`, default `.graphite`)

**Consumes:** `Accent` and `SessionState` (existing, from `NotchTheme.swift` / Core).

- [ ] **Step 1: Create `Palette.swift`**

```swift
import SwiftUI
import ClaudeNotchCore

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
    let textPrimary: Color, textSecondary: Color
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
         spark: Color? = nil) {
        self.surfaceTop = surfaceTop
        self.surfaceBottom = surfaceBottom
        self.innerBox = innerBox ?? Color.black.opacity(0.28)
        self.border = border ?? Color.white.opacity(0.12)
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
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
```

- [ ] **Step 2: Add `palette` to `NotchViewModel`** (in `NotchViews.swift`)

Find the `NotchViewModel` class and add the published property alongside the others:

```swift
    @Published var palette: Palette = .graphite
```

- [ ] **Step 3: Build (0 warnings)** — `swift build` → `Build complete!`, no warnings. (New symbols unused so far — fine.)
- [ ] **Step 4: Test** — `swift test` → `Executed 78 tests, with 0 failures`.
- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchApp/UI/Palette.swift Sources/ClaudeNotchApp/UI/NotchViews.swift
git commit -m "feat: add Palette single-source-of-truth + environment + graphite default

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `Themes.swift` — the 10 themes

**Files:**
- Create: `Sources/ClaudeNotchApp/UI/Themes.swift`

**Interfaces produced:** `struct Theme { let id: String; let name: String; let palette: Palette }`; `enum Themes { static let all: [Theme]; static let `default`: Theme }`.

**Consumes:** `Palette` (Task 1).

- [ ] **Step 1: Create `Themes.swift`**

```swift
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
        agentClaude: Color(hex: 0xD08770), agentCodex: Color(hex: 0x8FBCBB), agentGemini: Color(hex: 0x81A1C1),
        innerBox: Color(hex: 0x292E39), border: Color(hex: 0x4C566A), ended: Color(hex: 0x4C566A)))

    static let catppuccin = Theme(id: "catppuccin", name: "Catppuccin", palette: Palette(
        surfaceTop: Color(hex: 0x1E1E2E), surfaceBottom: Color(hex: 0x181825),
        textPrimary: Color(hex: 0xCDD6F4), textSecondary: Color(hex: 0xA6ADC8),
        working: Color(hex: 0x89B4FA), done: Color(hex: 0xA6E3A1), failed: Color(hex: 0xF38BA8),
        needsPermission: Color(hex: 0xFAB387), plan: Color(hex: 0xCBA6F7), question: Color(hex: 0x94E2D5),
        needsInputDot: Color(hex: 0xF9E2AF),
        agentClaude: Color(hex: 0xF5E0DC), agentCodex: Color(hex: 0x74C7EC), agentGemini: Color(hex: 0xB4BEFE),
        innerBox: Color(hex: 0x11111B), border: Color(hex: 0x313244), ended: Color(hex: 0x6C7086)))

    static let tokyoNight = Theme(id: "tokyo-night", name: "Tokyo Night", palette: Palette(
        surfaceTop: Color(hex: 0x1A1B26), surfaceBottom: Color(hex: 0x16161E),
        textPrimary: Color(hex: 0xC0CAF5), textSecondary: Color(hex: 0x9AA5CE),
        working: Color(hex: 0x7AA2F7), done: Color(hex: 0x9ECE6A), failed: Color(hex: 0xF7768E),
        needsPermission: Color(hex: 0xFF9E64), plan: Color(hex: 0xBB9AF7), question: Color(hex: 0x7DCFFF),
        needsInputDot: Color(hex: 0xE0AF68),
        agentClaude: Color(hex: 0xF7768E), agentCodex: Color(hex: 0x73DACA), agentGemini: Color(hex: 0x7AA2F7),
        innerBox: Color(hex: 0x101014), border: Color(hex: 0x292E42), ended: Color(hex: 0x565F89)))

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
        innerBox: Color(hex: 0x000000), border: Color(hex: 0x00FF41).opacity(0.22), ended: Color(hex: 0x2E7D32)))

    static let avengers = Theme(id: "avengers", name: "Avengers", palette: Palette(
        surfaceTop: Color(hex: 0x0E0B0B), surfaceBottom: Color(hex: 0x050303),
        textPrimary: Color(hex: 0xF5EFE6), textSecondary: Color(hex: 0xB9A98F),
        working: Color(hex: 0x3B82F6), done: Color(hex: 0x2FBF71), failed: Color(hex: 0xE23636),
        needsPermission: Color(hex: 0xE6A817), plan: Color(hex: 0x7C5CFF), question: Color(hex: 0x22B8CF),
        needsInputDot: Color(hex: 0xF5C518),
        agentClaude: Color(hex: 0xE6564B), agentCodex: Color(hex: 0xE6A817), agentGemini: Color(hex: 0x3B82F6),
        innerBox: Color(hex: 0x080505)))

    static let all: [Theme] = [graphite, midnight, highContrast, warm, nord,
                               catppuccin, tokyoNight, dune, matrix, avengers]
    static let `default` = graphite
}
```

- [ ] **Step 2: Build** — `swift build` → 0 warnings.
- [ ] **Step 3: Test** — `swift test` → 78/78.
- [ ] **Step 4: Commit**

```bash
git add Sources/ClaudeNotchApp/UI/Themes.swift
git commit -m "feat: add 10 built-in theme palettes

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Route `NotchComponents` onto the palette

Every component reads `@Environment(\.palette) var palette` and resolves colors from it instead of `accent.stroke`/`.softFill`. `CardContainer` uses palette surfaces + a **neutral** border. `AgentBadgeView` gets its tint from `palette.agentTint`. Text uses `palette.textPrimary/Secondary` instead of `.primary`/`.secondary`. (`Accent.stroke` still exists after this task — removed in Task 5 — so nothing breaks.)

**Files:** Modify `Sources/ClaudeNotchApp/UI/NotchComponents.swift`.

**Consumes:** `Palette` + `EnvironmentValues.palette` (Task 1). **Note:** the environment is injected by the roots in Task 4; until then components fall back to the `.graphite` default — build-clean and visually Graphite.

- [ ] **Step 1: `CardContainer` — palette surface + neutral border**

Replace the `body` of `CardContainer` with:

```swift
    @Environment(\.palette) private var palette

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
```

(Remove the two hard-coded `Color(red:…)` surface constants. The `accent` stored property stays — it's still the card's kind — but the border no longer uses it.)

- [ ] **Step 2: `AccentStrip` — dot+title from palette**

```swift
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
```

- [ ] **Step 3: `Badge` — take an explicit tint (unchanged call shape) + palette text default**

`Badge` already takes `tint`. Change only its default and neutral text source:

```swift
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
```

- [ ] **Step 4: `AgentBadgeView` — tint from palette**

```swift
struct AgentBadgeView: View {
    let agentID: String
    @Environment(\.palette) private var palette
    var body: some View {
        Badge(text: AgentBadge.forID(agentID).name, tint: palette.agentTint(agentID))
    }
}
```

(Use the **existing** `AgentBadge.forID(agentID).name` here — `AgentBadge.forID` still exists in this task; Task 5 renames it to `AgentBadge.name(agentID)`. The tint now comes from the palette, so `AgentBadge`'s own tint is no longer read.)

- [ ] **Step 5: `SessionContextStrip` — project text + terminal badge via palette**

```swift
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
```

- [ ] **Step 6: `IndexChip`, `OptionRow`, `ActionButton`, `ActivityLine` — resolve via palette**

`IndexChip`:
```swift
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
```

`OptionRow` — replace `accent.softFill`/`accent.stroke`/`.primary`/`.secondary` with palette:
```swift
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
```

`ActionButton` — foreground/background/border from palette (primary text = `palette.textPrimary`; ghost bg from `palette.border`-ish white; primary bg from `palette.accent`):
```swift
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
                .foregroundStyle(palette.textPrimary)
                .background(background, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
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
```
(Primary buttons keep white text for legibility over the accent fill — `palette.textPrimary` is a near-white in every theme.)

`ActivityLine`:
```swift
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
```

- [ ] **Step 7: Build** — `swift build` → 0 warnings. **Step 8: Test** → 78/78. **Step 9: Commit**

```bash
git add Sources/ClaudeNotchApp/UI/NotchComponents.swift
git commit -m "refactor: route notch components through the palette (neutral border, palette text)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Route `NotchViews` onto the palette + inject the environment

Migrate the remaining color reads in `NotchViews.swift` and inject `.environment(\.palette, vm.palette)` at both notch roots so switching recolors live.

**Files:** Modify `Sources/ClaudeNotchApp/UI/NotchViews.swift`.

**Consumes:** `Palette`, `NotchViewModel.palette` (Task 1); palette-routed components (Task 3).

- [ ] **Step 1: Inject the environment at `NotchExpandedView`**

In `NotchExpandedView.body`, add the environment modifier to the outer `VStack` (which already carries `.frame(width: NotchMetric.panelWidth)`):

```swift
        .frame(width: NotchMetric.panelWidth)
        .environment(\.palette, vm.palette)
```

- [ ] **Step 2: Inject the environment at `NotchCompactView`**

In `NotchCompactView.body`, add to the outer `HStack` (after `.padding(.horizontal, 8)`):

```swift
        .padding(.horizontal, 8)
        .environment(\.palette, vm.palette)
```

- [ ] **Step 3: `notice` text via palette**

In `NotchExpandedView`, the notice line currently uses `.foregroundStyle(.red)`. It renders inside the injected environment, so read the palette. Change the notice `Text` to resolve the color — simplest: since the `VStack` has the palette in environment, add `@Environment(\.palette) private var palette` to `NotchExpandedView` and use `palette.failed`:

```swift
    @Environment(\.palette) private var palette
```
```swift
            if let notice = vm.notice {
                Text(notice).font(.system(size: 11)).foregroundStyle(palette.failed)
                    .padding(.horizontal, 12).padding(.bottom, 10)
            }
```

- [ ] **Step 4: `UsageHeader` spark + text via palette**

Add `@Environment(\.palette) private var palette` to `UsageHeader` and replace `.yellow.opacity(0.85)` / `.secondary`:

```swift
                Text("✦").font(.system(size: 12)).foregroundStyle(palette.spark)
                Text("\(t.count) active session\(t.count == 1 ? "" : "s")")
                    .font(.system(size: 11)).foregroundStyle(palette.textSecondary)
                Spacer(minLength: 8)
                Text(Self.readout(t)).font(.system(size: 11)).foregroundStyle(palette.textSecondary)
```

- [ ] **Step 5: `SessionRow` — dot + text + right-column via palette**

Add `@Environment(\.palette) private var palette` to `SessionRow`. Replace `session.state.dotColor` with `palette.dot(for: session.state)`, `.secondary` with `palette.textSecondary`, and the state label color (`session.state.dotColor`) with `palette.dot(for: session.state)`:

```swift
            Circle().fill(palette.dot(for: session.state)).frame(width: 9, height: 9)
                .shadow(color: palette.dot(for: session.state).opacity(0.5), radius: 4)
                .padding(.top, 4)
```
```swift
                    Text(session.projectName).font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.textPrimary).lineLimit(1)
                    if let model = session.usage?.model {
                        Text(ModelName.friendly(model)).font(.system(size: 11)).foregroundStyle(palette.textSecondary)
                    }
```
```swift
                Text("\(session.state.shortLabel) \(Format.duration(now.timeIntervalSince(session.stateSince)))")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(palette.dot(for: session.state))
```
```swift
                if let usage = session.usage, usage.tokens.total > 0 {
                    Text(Format.usage(usage)).font(.system(size: 10.5)).foregroundStyle(palette.textSecondary)
                }
```
(The "No active Claude Code sessions" text and `projectName` title: also switch `.foregroundStyle(.secondary)`/default to `palette.textSecondary`/`palette.textPrimary` wherever they appear in `NotchExpandedView`/`SessionRow`.)

- [ ] **Step 6: `CountDot` + `NotchCompactView` — palette colors**

Change `CountDot` to resolve from the palette by accent, and update the call sites to pass an `Accent`:

```swift
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
```
Call sites in `NotchCompactView`:
```swift
            if waiting > 0 { CountDot(accent: .permission, count: waiting) }
            if working > 0 { CountDot(accent: .working,    count: working) }
            if done > 0    { CountDot(accent: .done,       count: done) }
            if failed > 0  { CountDot(accent: .failed,     count: failed) }
```

- [ ] **Step 7: `DecisionCardView` diff/plan/diffstat via palette**

Add `@Environment(\.palette) private var palette` to `DecisionCardView`. Replace:
- `planBody` border `Accent.plan.stroke.opacity(0.2)` → `palette.plan.opacity(0.2)`; the mono box `Color.black.opacity(0.3)` → `palette.innerBox`.
- `previewBody` box `Color.black.opacity(0.3)` → `palette.innerBox`; border `.white.opacity(0.08)` → `palette.border`; the diff line colors `line.kind == .added ? .green : line.kind == .removed ? .red : .primary` → `line.kind == .added ? palette.diffAdd : line.kind == .removed ? palette.diffRemove : palette.textPrimary`; the file caption `.secondary` → `palette.textSecondary`.
- `diffStat`: `.green`/`.red` → `palette.diffAdd`/`palette.diffRemove`.
- The header/question/fallback texts using `.secondary` → `palette.textSecondary`; question text default → `palette.textPrimary`.
- "N more waiting" `.secondary` → `palette.textSecondary`.

- [ ] **Step 8: Build** — `swift build` → 0 warnings. **Step 9: Test** → 78/78. **Step 10: Commit**

```bash
git add Sources/ClaudeNotchApp/UI/NotchViews.swift
git commit -m "refactor: route notch views onto the palette + inject palette environment

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Cleanup — demote `Accent`, make `AgentBadge` name-only, drop `dotColor`

Remove the now-dead old color API so the palette is the only source.

**Files:** Modify `Sources/ClaudeNotchApp/UI/NotchTheme.swift`; touch `NotchComponents.swift` only for the `AgentBadge.name` rename.

- [ ] **Step 1: Strip colors from `Accent`** — in `NotchTheme.swift`, delete the `var stroke: Color` and `var softFill: Color` computed properties from `Accent`. Keep the `enum Accent { case permission, question, plan, working, done, failed, neutral }` declaration, `NotchMetric`, `DecisionKind.accent`, and `SessionState.surfaceAccent`.

- [ ] **Step 2: Remove `SessionState.dotColor`** — delete the `var dotColor: Color { … }` extension (now replaced everywhere by `palette.dot(for:)`). Keep `shortLabel`, `glyph`, `label`, `surfaceAccent`.

- [ ] **Step 3: Make `AgentBadge` name-only** — replace the `AgentBadge` struct's `forID` (which returned name+tint) with a name lookup, since tints now come from the palette:

```swift
enum AgentBadge {
    /// Friendly display name for an agent id (tint comes from the active Palette).
    static func name(_ id: String) -> String {
        switch id {
        case "claude": return "Claude"
        case "codex":  return "Codex"
        case "gemini": return "Gemini"
        default:       return id.isEmpty ? "agent" : id.capitalized
        }
    }
}
```

- [ ] **Step 4: Update `AgentBadgeView`** — in `NotchComponents.swift`, change `AgentBadge.forID(agentID).name` to `AgentBadge.name(agentID)`.

- [ ] **Step 5: Grep guard** — run:
```bash
grep -nE '\.(blue|green|red|orange|yellow|purple)\b' Sources/ClaudeNotchApp/UI/NotchViews.swift Sources/ClaudeNotchApp/UI/NotchComponents.swift
```
Expected: **no output** (all state colors now come from the palette).

- [ ] **Step 6: Build** — `swift build` → 0 warnings. **Step 7: Test** → 78/78. **Step 8: Commit**

```bash
git add Sources/ClaudeNotchApp/UI/NotchTheme.swift Sources/ClaudeNotchApp/UI/NotchComponents.swift
git commit -m "refactor: remove dead Accent colors + dotColor; AgentBadge is name-only

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: `ThemeStore` + menu switcher + wiring

Add persistence and the user-facing switch.

**Files:** Create `Sources/ClaudeNotchApp/UI/ThemeStore.swift`; modify `Sources/ClaudeNotchApp/AppCoordinator.swift`.

**Consumes:** `Themes`, `NotchViewModel.palette`. **Note on VM access:** `AppCoordinator` already holds the `NotchController` (`notch`). Add a `NotchController.setPalette(_:)` that assigns `vm.palette`, and call it from the coordinator (the VM is private to the controller).

- [ ] **Step 1: `ThemeStore.swift`**

```swift
import Foundation

/// Holds the theme list + the current selection, persisted to UserDefaults.
final class ThemeStore {
    private let key = "notch.themeID"
    let all: [Theme] = Themes.all
    private(set) var current: Theme

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.string(forKey: key)
        self.current = Themes.all.first { $0.id == saved } ?? Themes.default
    }
    private let defaults: UserDefaults

    /// Select by id; persists. Unknown id is ignored. Returns the new current theme.
    @discardableResult
    func select(id: String) -> Theme {
        guard let t = all.first(where: { $0.id == id }) else { return current }
        current = t
        defaults.set(id, forKey: key)
        return t
    }
}
```

- [ ] **Step 2: `NotchController.setPalette`** — add to `NotchController`:

```swift
    /// Apply a theme palette; the notch recolors live via the injected environment.
    public func setPalette(_ palette: Palette) { vm.palette = palette }
```

- [ ] **Step 3: Wire the store in `AppCoordinator`** — add a stored `private let themeStore = ThemeStore()`; in `applicationDidFinishLaunching` (after the notch is created), apply the persisted theme: `notch.setPalette(themeStore.current.palette)`.

- [ ] **Step 4: Add the Theme submenu** — in `setupMenuBar()`, before the separator/Quit, insert:

```swift
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
```
(Keep a reference to `themeMenu` — e.g. `private var themeMenu: NSMenu?` — so the check state can be refreshed on selection.)

- [ ] **Step 5: `selectTheme` action** — add:

```swift
    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        let theme = themeStore.select(id: id)
        notch.setPalette(theme.palette)
        // refresh checkmarks
        themeMenu?.items.forEach { $0.state = ($0.representedObject as? String == theme.id) ? .on : .off }
    }
```

- [ ] **Step 6: Build** — `swift build` → 0 warnings. **Step 7: Test** → 78/78. **Step 8: Commit**

```bash
git add Sources/ClaudeNotchApp/UI/ThemeStore.swift Sources/ClaudeNotchApp/UI/NotchController.swift Sources/ClaudeNotchApp/AppCoordinator.swift
git commit -m "feat: add ThemeStore + menu-bar Theme switcher (persisted, live recolor)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Verification (human-pending GUI e2e)

Per-task = `swift build` (0 warnings) + `swift test` 78/78 + the Task 5 grep guard. Final acceptance is live: run the app, open the `◗` **Theme ▸** submenu, switch through all 10 — the notch recolors immediately, the checkmark tracks the active theme, and the choice survives an app relaunch (persisted). Confirm each theme keeps the six states distinguishable and text legible over its own surface (spec §10).

## Self-Review

- **Spec coverage:** §7 Palette → Task 1; the 10 themes (§5) → Task 2; component consolidation (§6/§11) → Task 3; view consolidation + live injection (§6/§7/§11) → Task 4; dead-API removal + "no raw colors" (§1 criterion 1) → Task 5; `Theme`/`ThemeStore`/persistence/menu (§7/§11) → Task 6. Neutral border (§4.4) → Task 3 Step 1. needsInput dot (§4.6) → `Palette.dot` (Task 1) + Task 4 Step 5. Agent tints themeable (§4.5) → `Palette.agentTint` (Task 1) + Tasks 3/5. Persistence + live recolor (§4.2/§4.3) → Task 6 + Task 4 injection.
- **Placeholder scan:** none — full code for new files; exact before→after for edits; every step has a command + expected result.
- **Type consistency:** `Palette.accent(_:)`, `softFill(_:)`, `dot(for:)`, `agentTint(_:)`, `Themes.all`/`.default`, `Theme{id,name,palette}`, `ThemeStore.select(id:)`/`.current`/`.all`, `NotchController.setPalette(_:)`, `NotchViewModel.palette`, `Color(hex:)`, `AgentBadge.name(_:)`, `CountDot(accent:count:)` are used identically across tasks. `Accent` cases and `SessionState` cases match the source. Build-clean ordering verified: new API added (1–2) → readers migrated while old `Accent` colors still present (3–4) → old API removed only after all readers migrated (5) → store/menu wired (6).
