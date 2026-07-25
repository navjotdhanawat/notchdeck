# ClaudeNotch v2 — Visual Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring all four notch surfaces (decision cards, glance rows, usage header, compact pill) up to the v2 mockup via a shared SwiftUI design-system layer — presentation only, no behavior change.

**Architecture:** Extract a small design-system layer — `NotchTheme.swift` (accent tokens, state/kind → accent mappings, metrics, agent badge style) and `NotchComponents.swift` (reusable views: card shell, accent strip, session-context strip, index chip, option row, action button, badge, activity line) — then rebuild the existing views in `NotchViews.swift` on top of it. No Core, transport, hook, or decision-logic changes.

**Tech Stack:** Swift 5.9+, SwiftUI + AppKit, DynamicNotchKit (notch overlay), SwiftPM. macOS app target `ClaudeNotchApp`; domain in `ClaudeNotchCore`.

## Global Constraints

- **Presentation-only.** No changes to `ClaudeNotchCore`, transport, hooks, `DecisionBroker`, `DecisionEncoder`, jump logic, or agent/terminal seams. The decision/answer wire behavior must stay byte-for-byte identical.
- **No new test cases.** Repo + user policy: never add test files/cases on our own initiative. The codebase has **no SwiftUI view tests**; do not invent any. Verification for every task = `swift build` with **0 warnings** AND `swift test` still **78/78 passing** (the guardrail proving behavior is unchanged). Update an existing test only if a symbol it references is renamed (none are planned).
- **Honesty fences (hard requirement).** No ⌘-key chips that can't fire (panel is click-only, non-activating) → use numbered index chips (visual only). No rate-limit bars. No "$today"/day-scoped claims — the usage header is labeled "N active session(s)" + tokens/cost across those sessions. The mockup's `You:` prompt line is **not** built (no data source).
- **Locked visual decisions:** needsInput → **teal** surface accent but the state **dot stays yellow** (`SessionState.dotColor` unchanged); subtle **per-agent badge tint** (Claude/Codex/Gemini), neutral terminal badge; numbered index chips `1/2/3`.
- **Commit policy:** local git only, no remote, no push. Conventional-commit messages, **no JIRA prefix** (this project is exempt). Every commit message ends with the trailer:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- **Branch:** all work on `feat/claudenotch-v2-visual-polish` (already created; spec + mockup already committed there).
- **Build/test commands:** `swift build` and `swift test` run from repo root `/Users/navjotdhanawat/Workspace/claude-notch`.

## File Structure

- **Create** `Sources/ClaudeNotchApp/UI/NotchTheme.swift` — design tokens: `Accent`, `NotchMetric`, `AgentBadge`, `DecisionKind.accent`, `SessionState.surfaceAccent`. Single source of truth for the accent-per-state system.
- **Create** `Sources/ClaudeNotchApp/UI/NotchComponents.swift` — reusable views: `CardContainer`, `AccentStrip`, `Badge`, `AgentBadgeView`, `SessionContextStrip`, `IndexChip`, `OptionRow`, `ActionButton`, `ActivityLine`.
- **Modify** `Sources/ClaudeNotchApp/UI/NotchViews.swift` — rebuild `NotchExpandedView`, `DecisionCardView`, `SessionRow`, `NotchCompactView`; add `UsageHeader` + `CountDot`. Keep `NotchViewModel`, `Format`, `ModelName`, and the existing `SessionState` extensions (`glyph`, `label`, `dotColor`, `shortLabel`).

No other files change. `NotchController.swift` / `AppCoordinator.swift` are **not** modified — `NotchExpandedView` already holds `vm.sessions`, so the decision card gets its session by local lookup.

---

### Task 1: Design tokens (`NotchTheme.swift`)

**Files:**
- Create: `Sources/ClaudeNotchApp/UI/NotchTheme.swift`

**Interfaces:**
- Produces:
  - `enum Accent { case permission, question, plan, working, done, failed, neutral }` with `var stroke: Color` and `var softFill: Color`.
  - `enum NotchMetric` with `static let corner, cardPadding, hairline, badgeCorner, panelWidth: CGFloat`.
  - `struct AgentBadge { let name: String; let tint: Color; static func forID(_ id: String) -> AgentBadge }`.
  - `extension DecisionKind { var accent: Accent }`.
  - `extension SessionState { var surfaceAccent: Accent }` (distinct from the existing `dotColor`, which is unchanged).

- [ ] **Step 1: Create the file with the full token set**

```swift
import SwiftUI
import ClaudeNotchCore

/// Semantic accent for a notch surface — the single source of truth for the
/// accent-per-state system. Replaces scattered `.orange`/`.purple` literals.
enum Accent {
    case permission, question, plan, working, done, failed, neutral

    var stroke: Color {
        switch self {
        case .permission: return Color(red: 1.00, green: 0.624, blue: 0.039) // amber  #FF9F0A
        case .question:   return Color(red: 0.353, green: 0.784, blue: 0.980) // teal   #5AC8FA
        case .plan:       return Color(red: 0.655, green: 0.545, blue: 0.980) // indigo #A78BFA
        case .working:    return Color(red: 0.039, green: 0.518, blue: 1.00)  // blue   #0A84FF
        case .done:       return Color(red: 0.188, green: 0.820, blue: 0.345) // green  #30D158
        case .failed:     return Color(red: 1.00, green: 0.271, blue: 0.227)  // red    #FF453A
        case .neutral:    return Color.white.opacity(0.55)
        }
    }

    /// Soft translucent fill for card backgrounds / option rows / strips.
    var softFill: Color { stroke.opacity(0.14) }
}

/// Shared spacing/sizing so every surface reads as one system.
enum NotchMetric {
    static let corner: CGFloat = 14
    static let cardPadding: CGFloat = 12
    static let hairline: CGFloat = 1
    static let badgeCorner: CGFloat = 6
    static let panelWidth: CGFloat = 360
}

/// Friendly name + tint for an agent badge, keyed by `Session.agentID`.
/// Mirrors the `ModelName` mapping precedent; keeps the view layer free of Core agent types.
struct AgentBadge {
    let name: String
    let tint: Color

    static func forID(_ id: String) -> AgentBadge {
        switch id {
        case "claude": return AgentBadge(name: "Claude", tint: Color(red: 0.890, green: 0.569, blue: 0.471)) // terracotta
        case "codex":  return AgentBadge(name: "Codex",  tint: Color(red: 0.373, green: 0.816, blue: 0.690)) // teal-green
        case "gemini": return AgentBadge(name: "Gemini", tint: Color(red: 0.561, green: 0.690, blue: 0.976)) // periwinkle
        default:       return AgentBadge(name: id.isEmpty ? "agent" : id.capitalized, tint: Color.white.opacity(0.6))
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
    /// Surface accent for cards/activity lines. Note: `dotColor` is intentionally
    /// separate — needsInput's surface is teal here, but its dot stays yellow.
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
```

- [ ] **Step 2: Build to verify it compiles with no warnings**

Run: `swift build`
Expected: `Build complete!` with no warning lines. (The new symbols are unused so far — Swift does not warn on unused types/methods.)

- [ ] **Step 3: Run the test suite (guardrail)**

Run: `swift test`
Expected: all pass — `Executed 78 tests, with 0 failures`.

- [ ] **Step 4: Commit**

```bash
git add Sources/ClaudeNotchApp/UI/NotchTheme.swift
git commit -m "feat: add NotchTheme design tokens (accent-per-state, metrics, agent badge)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Reusable components (`NotchComponents.swift`)

**Files:**
- Create: `Sources/ClaudeNotchApp/UI/NotchComponents.swift`

**Interfaces:**
- Consumes (Task 1): `Accent`, `NotchMetric`, `AgentBadge`.
- Produces:
  - `struct CardContainer<Content: View>: View` — `init(accent: Accent, @ViewBuilder content: () -> Content)`.
  - `struct AccentStrip: View` — `init(title: String, accent: Accent)`.
  - `struct Badge: View` — `init(text: String, tint: Color = .white.opacity(0.6))`.
  - `struct AgentBadgeView: View` — `init(agentID: String)`.
  - `struct SessionContextStrip: View` — `init(session: Session?)`.
  - `struct IndexChip: View` — `init(n: Int, accent: Accent = .question)`.
  - `struct OptionRow: View` — `init(index: Int, label: String, description: String?, accent: Accent, action: @escaping () -> Void)`.
  - `enum ActionButtonStyle { case ghost; case primary(Accent) }` and `struct ActionButton: View` — `init(title: String, style: ActionButtonStyle, fill: Bool = true, action: @escaping () -> Void)`.
  - `struct ActivityLine: View` — `init(text: String, accent: Accent)`.

- [ ] **Step 1: Create the file with all components**

```swift
import SwiftUI
import ClaudeNotchCore

/// Consistent card shell: material background, themed corner + padding, hairline accent border.
struct CardContainer<Content: View>: View {
    let accent: Accent
    @ViewBuilder var content: Content

    init(accent: Accent, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        content
            .padding(NotchMetric.cardPadding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: NotchMetric.corner))
            .overlay(
                RoundedRectangle(cornerRadius: NotchMetric.corner)
                    .strokeBorder(accent.stroke.opacity(0.35), lineWidth: NotchMetric.hairline)
            )
    }
}

/// The colored top strip of a card: a glowing dot + accent-colored title.
struct AccentStrip: View {
    let title: String
    let accent: Accent
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(accent.stroke).frame(width: 8, height: 8)
                .shadow(color: accent.stroke.opacity(0.6), radius: 4)
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(accent.stroke)
            Spacer(minLength: 0)
        }
    }
}

/// A small pill: agent badges pass a tint; terminal/model badges use the neutral default.
struct Badge: View {
    let text: String
    var tint: Color = .white.opacity(0.6)
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .foregroundStyle(tint)
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: NotchMetric.badgeCorner))
            .overlay(RoundedRectangle(cornerRadius: NotchMetric.badgeCorner)
                .strokeBorder(tint.opacity(0.28), lineWidth: 1))
    }
}

/// Agent badge with per-agent tint, resolved from `Session.agentID`.
struct AgentBadgeView: View {
    let agentID: String
    var body: some View {
        let a = AgentBadge.forID(agentID)
        Badge(text: a.name, tint: a.tint)
    }
}

/// project · [agent] · [terminal] context for a decision card. Degrades to empty when nil.
struct SessionContextStrip: View {
    let session: Session?
    var body: some View {
        if let s = session {
            HStack(spacing: 7) {
                Text(s.projectName).font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary).lineLimit(1)
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
    var body: some View {
        Text("\(n)")
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .frame(width: 22, height: 22)
            .foregroundStyle(accent.stroke)
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(accent.stroke.opacity(0.3), lineWidth: 1))
    }
}

/// A pressable AskUserQuestion option: index chip + label + optional description.
struct OptionRow: View {
    let index: Int
    let label: String
    let description: String?
    let accent: Accent
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 11) {
                IndexChip(n: index, accent: accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
                    if let d = description, !d.isEmpty {
                        Text(d).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8).padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accent.softFill.opacity(hovering ? 1.4 : 1.0),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(accent.stroke.opacity(hovering ? 0.5 : 0.22), lineWidth: 1))
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
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: fill ? .infinity : nil)
                .padding(.vertical, 9).padding(.horizontal, fill ? 12 : 12)
                .foregroundStyle(foreground)
                .background(background, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var foreground: Color {
        switch style {
        case .ghost: return .white
        case .primary: return .white
        }
    }
    private var background: Color {
        switch style {
        case .ghost: return Color.white.opacity(hovering ? 0.15 : 0.09)
        case .primary(let a): return a.stroke.opacity(hovering ? 1.0 : 0.85)
        }
    }
    private var border: Color {
        switch style {
        case .ghost: return Color.white.opacity(0.10)
        case .primary(let a): return a.stroke.opacity(0.9)
        }
    }
}

/// One-line "what it's doing now", colored by the session's surface accent.
struct ActivityLine: View {
    let text: String
    let accent: Accent
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(accent == .neutral ? Color.secondary : accent.stroke)
            .lineLimit(1)
    }
}
```

- [ ] **Step 2: Build to verify it compiles with no warnings**

Run: `swift build`
Expected: `Build complete!` with no warning lines.

- [ ] **Step 3: Run the test suite (guardrail)**

Run: `swift test`
Expected: `Executed 78 tests, with 0 failures`.

- [ ] **Step 4: Commit**

```bash
git add Sources/ClaudeNotchApp/UI/NotchComponents.swift
git commit -m "feat: add reusable notch UI components (card, strip, chips, buttons, badges)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Rebuild the decision card (`DecisionCardView` + `NotchExpandedView`)

Rebuild the headline surface on the design system: accent strip + session-context strip + kind-specific body + action buttons + a prominent "Answer in terminal" footer. **Decision logic is unchanged** — same `Decision` values, same single-select/terminal fallback rule.

**Files:**
- Modify: `Sources/ClaudeNotchApp/UI/NotchViews.swift` — replace `struct NotchExpandedView` and `struct DecisionCardView` (whole structs).

**Interfaces:**
- Consumes (Tasks 1–2): `CardContainer`, `AccentStrip`, `SessionContextStrip`, `OptionRow`, `ActionButton`, `Accent`, `NotchMetric`, `DecisionKind.accent`.
- Produces: `DecisionCardView(request:session:remaining:onDecide:onAnswerInTerminal:)` — new `session: Session?` param supplies the context strip. `NotchExpandedView` resolves it via `vm.sessions.first { $0.key == req.sessionKey }`.
- Depends on: `SessionRow` still exists (unchanged in this task) and `UsageHeader` does **not** yet exist — so `NotchExpandedView`'s session list here renders rows only (no header). Task 5 inserts the header.

- [ ] **Step 1: Replace `NotchExpandedView` with the branch that passes `session` to the card**

Replace the existing `struct NotchExpandedView { ... }` with:

```swift
struct NotchExpandedView: View {
    @ObservedObject var vm: NotchViewModel
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
                Text(notice).font(.system(size: 11)).foregroundStyle(.red)
                    .padding(.horizontal, 12).padding(.bottom, 10)
            }
        }
        .frame(width: NotchMetric.panelWidth)
    }

    @ViewBuilder private var sessionList: some View {
        VStack(alignment: .leading, spacing: 6) {
            if vm.sessions.isEmpty {
                Text("No active Claude Code sessions").foregroundStyle(.secondary)
            } else {
                ForEach(vm.sessions) { s in
                    Button { vm.onJump?(s) } label: { SessionRow(session: s, now: vm.now) }
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
    }
}
```

- [ ] **Step 2: Replace `DecisionCardView` with the design-system rebuild**

Replace the existing `struct DecisionCardView { ... }` with:

```swift
struct DecisionCardView: View {
    let request: DecisionRequest
    let session: Session?
    let remaining: Int
    var onDecide: ((DecisionRequest, Decision) -> Void)?
    var onAnswerInTerminal: ((DecisionRequest) -> Void)?

    var body: some View {
        CardContainer(accent: request.kind.accent) {
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
        case .question:                    return "Claude asks"
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
                Text("\(remaining) more waiting").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func questionBody(_ questions: [QuestionSpec]) -> some View {
        if let q = questions.first, questions.count == 1, !q.multiSelect {
            if let header = q.header, !header.isEmpty {
                Text(header).font(.caption).foregroundStyle(.secondary)
            }
            Text(q.question).font(.system(size: 14, weight: .medium))
            VStack(spacing: 8) {
                ForEach(Array(q.options.enumerated()), id: \.offset) { idx, opt in
                    OptionRow(index: idx + 1, label: opt.label, description: opt.description, accent: .question) {
                        onDecide?(request, .answer(answers: [q.question: opt.label]))
                    }
                }
            }
        } else {
            Text("Answer this one in the terminal.").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func planBody(_ text: String) -> some View {
        ScrollView {
            Text(text).font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 150)
        .padding(8)
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Accent.plan.stroke.opacity(0.2), lineWidth: 1))
    }

    @ViewBuilder private func previewBody(_ preview: ToolPreview) -> some View {
        ScrollView {
            Group {
                switch preview {
                case let .diff(file, lines):
                    VStack(alignment: .leading, spacing: 1) {
                        Text(file).font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text((line.kind == .added ? "+ " : line.kind == .removed ? "- " : "  ") + line.text)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(line.kind == .added ? .green : line.kind == .removed ? .red : .primary)
                        }
                    }
                case let .command(cmd):
                    Text(cmd).font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                case let .raw(s):
                    Text(s).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 150)
        .padding(8)
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }
}
```

- [ ] **Step 3: Build to verify it compiles with no warnings**

Run: `swift build`
Expected: `Build complete!` with no warning lines.

- [ ] **Step 4: Run the test suite (guardrail — decision wire behavior unchanged)**

Run: `swift test`
Expected: `Executed 78 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchApp/UI/NotchViews.swift
git commit -m "feat: rebuild decision card on the design system (accent strip, context, index-chip options)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Rich glance row (`SessionRow`)

**Files:**
- Modify: `Sources/ClaudeNotchApp/UI/NotchViews.swift` — replace `struct SessionRow` (whole struct).

**Interfaces:**
- Consumes (Tasks 1–2): `ActivityLine`, `AgentBadgeView`, `Badge`, `SessionState.surfaceAccent`.
- Consumes (existing, keep): `SessionState.dotColor`, `SessionState.shortLabel`, `Format.duration`, `Format.usage`, `ModelName.friendly`.
- Produces: `SessionRow(session:now:)` — same signature as today (used unchanged by `NotchExpandedView`).

- [ ] **Step 1: Replace `SessionRow` with the rich row**

Replace the existing `struct SessionRow { ... }` with:

```swift
struct SessionRow: View {
    let session: Session
    let now: Date

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(session.state.dotColor).frame(width: 9, height: 9)
                .shadow(color: session.state.dotColor.opacity(0.5), radius: 4)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.projectName).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    if let model = session.usage?.model {
                        Text(ModelName.friendly(model)).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                if let action = session.currentAction ?? session.currentTool {
                    ActivityLine(text: action, accent: session.state.surfaceAccent)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(session.state.shortLabel) \(Format.duration(now.timeIntervalSince(session.stateSince)))")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(session.state.dotColor)
                HStack(spacing: 5) {
                    AgentBadgeView(agentID: session.agentID)
                    if let term = session.terminal.appName, !term.isEmpty {
                        Badge(text: term.replacingOccurrences(of: ".app", with: ""))
                    }
                }
                if let usage = session.usage, usage.tokens.total > 0 {
                    Text(Format.usage(usage)).font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())   // whole row is the click/hit target
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
    }
}
```

- [ ] **Step 2: Build to verify it compiles with no warnings**

Run: `swift build`
Expected: `Build complete!` with no warning lines.

- [ ] **Step 3: Run the test suite (guardrail)**

Run: `swift test`
Expected: `Executed 78 tests, with 0 failures`.

- [ ] **Step 4: Commit**

```bash
git add Sources/ClaudeNotchApp/UI/NotchViews.swift
git commit -m "feat: rebuild glance row with activity line + agent/terminal badges

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Usage header (`UsageHeader` + `NotchExpandedView` insert)

**Files:**
- Modify: `Sources/ClaudeNotchApp/UI/NotchViews.swift` — add `struct UsageHeader`; insert one line into `NotchExpandedView.sessionList`.

**Interfaces:**
- Consumes (existing): `Session.usage`, `SessionUsage.tokens.total`, `SessionUsage.costUSD`, `Format.tokens`.
- Produces: `UsageHeader(sessions: [Session])` — renders `✦  N active session(s)   <tokens> tok · $X` across sessions with usage; renders nothing when no session has tokens. Honest label — not day-scoped.

- [ ] **Step 1: Add the `UsageHeader` struct**

Add this struct to `NotchViews.swift` (e.g. directly after `SessionRow`):

```swift
/// Honest usage summary across active sessions: total tokens + cost we already track.
/// NOT a calendar-day total and NOT a rate-limit readout — labeled for exactly what it is.
struct UsageHeader: View {
    let sessions: [Session]

    var body: some View {
        let t = Self.totals(sessions)
        if t.tokens > 0 {
            HStack(spacing: 8) {
                Text("✦").font(.system(size: 12)).foregroundStyle(.yellow.opacity(0.85))
                Text("\(t.count) active session\(t.count == 1 ? "" : "s")")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(Self.readout(t)).font(.system(size: 11)).foregroundStyle(.secondary)
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
```

- [ ] **Step 2: Insert `UsageHeader` at the top of the session list**

In `NotchExpandedView.sessionList`, add the header above the `ForEach`. Replace:

```swift
            } else {
                ForEach(vm.sessions) { s in
                    Button { vm.onJump?(s) } label: { SessionRow(session: s, now: vm.now) }
                        .buttonStyle(.plain)
                }
            }
```

with:

```swift
            } else {
                UsageHeader(sessions: vm.sessions)
                ForEach(vm.sessions) { s in
                    Button { vm.onJump?(s) } label: { SessionRow(session: s, now: vm.now) }
                        .buttonStyle(.plain)
                }
            }
```

- [ ] **Step 3: Build to verify it compiles with no warnings**

Run: `swift build`
Expected: `Build complete!` with no warning lines.

- [ ] **Step 4: Run the test suite (guardrail)**

Run: `swift test`
Expected: `Executed 78 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeNotchApp/UI/NotchViews.swift
git commit -m "feat: add honest usage header (tokens/cost across active sessions)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Polish the compact pill (`NotchCompactView` + `CountDot`)

**Files:**
- Modify: `Sources/ClaudeNotchApp/UI/NotchViews.swift` — replace `struct NotchCompactView`; add `struct CountDot`.

**Interfaces:**
- Consumes: only SwiftUI + `NotchViewModel` (no new tokens strictly required; uses plain `Color`s to match the dot legend).
- Produces: `CountDot(color:count:)` helper. Preserves the existing count semantics (waiting = needsInput + needsPermission, working, done, failed).

- [ ] **Step 1: Replace `NotchCompactView` and add `CountDot`**

Replace the existing `struct NotchCompactView { ... }` with:

```swift
struct NotchCompactView: View {
    @ObservedObject var vm: NotchViewModel
    var body: some View {
        let waiting = vm.sessions.filter { $0.state == .needsInput || $0.state == .needsPermission }.count
        let working = vm.sessions.filter { $0.state == .working }.count
        let done = vm.sessions.filter { $0.state == .done }.count
        let failed = vm.sessions.filter { $0.state == .failed }.count
        HStack(spacing: 9) {
            if waiting > 0 { CountDot(color: .orange, count: waiting) }
            if working > 0 { CountDot(color: .blue,   count: working) }
            if done > 0    { CountDot(color: .green,  count: done) }
            if failed > 0  { CountDot(color: .red,    count: failed) }
        }
        .padding(.horizontal, 8)
    }
}

/// A crisp colored dot + count for the compact pill (replaces the emoji glyphs).
struct CountDot: View {
    let color: Color
    let count: Int
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.6), radius: 3)
            Text("\(count)").font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary)
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles with no warnings**

Run: `swift build`
Expected: `Build complete!` with no warning lines.

- [ ] **Step 3: Run the test suite (guardrail)**

Run: `swift test`
Expected: `Executed 78 tests, with 0 failures`.

- [ ] **Step 4: Commit**

```bash
git add Sources/ClaudeNotchApp/UI/NotchViews.swift
git commit -m "feat: polish compact pill with crisp dots + counts

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Verification (human-pending GUI e2e)

Automated verification is `swift build` (0 warnings) + `swift test` (78/78) per task. The visual result cannot be screenshotted (DynamicNotchKit overlay), so a human runs the app once at the end and confirms by eye (see spec §10): decision cards (permission diff + Deny/Allow/Allow-for-session, ask index-chip options answer in place, plan Approve/Request-changes), rich rows (dot · title · activity · tinted agent + neutral terminal badge · elapsed, click jumps), usage header appears/hides correctly, compact pill dots, needsInput = teal card + yellow dot.

## Self-Review

- **Spec coverage:** §5 foundation → Tasks 1–2. §6.1 decision cards → Task 3. §6.2 rich rows → Task 4. §6.3 usage header → Task 5. §6.4 compact pill → Task 6. §4 locked decisions: numbered chips (IndexChip, Task 2/3), usage tokens/cost-only + honest label (UsageHeader, Task 5), You:-line dropped (never built), needsInput teal-panel/yellow-dot (`surfaceAccent` vs `dotColor`, Tasks 1/3/4), per-agent tint (`AgentBadge`/`AgentBadgeView`, Tasks 1/2). §7 no model changes (all inputs pre-existing). §8 no new tests (build+test guardrail each task). All covered.
- **Placeholder scan:** none — every code step contains full source; every command has an expected result.
- **Type consistency:** `DecisionKind.accent`, `SessionState.surfaceAccent`, `AgentBadge.forID`, `AgentBadgeView(agentID:)`, `CardContainer(accent:content:)`, `OptionRow(index:label:description:accent:action:)`, `ActionButton(title:style:fill:action:)`, `UsageHeader(sessions:)`, `DecisionCardView(request:session:remaining:onDecide:onAnswerInTerminal:)` are used identically wherever referenced. Core references (`ToolPreview.diff/command/raw`, `DiffLine.Kind.added/.removed`, `SessionUsage.tokens.total/.costUSD/.model`, `TokenUsage.total`, `Decision.allow(scope:)/.deny(reason:)/.answer(answers:)`) match the source verified during planning.
