# ClaudeNotch — Theme System (color consolidation + switchable themes) — Design Spec

- **Status:** Approved (design). Ready for implementation planning.
- **Date:** 2026-07-24
- **Builds on:** the v2 visual-polish pass (merged `282a807`) + the width/dark-card fix (merged `aca2730`). See `docs/superpowers/specs/2026-07-24-claudenotch-v2-visual-polish-design.md`.
- **Repo policy:** Local git only. No remote, nothing pushed. No JIRA tracking for this project.

---

## 1. Purpose & goals

Two intertwined problems, one solution:

1. **Color inconsistency.** Colors come from four uncoordinated sources with overlapping-but-different values for the same meaning: the `Accent` tokens (precise hex), `SessionState.dotColor` (raw `.blue`/`.green`/…), `CountDot` call-sites (raw again), and scattered raw literals (diff `+/−`, `✦`, notice). "Working" is `#0A84FF` in one place and raw `.blue` in another; "permission" amber collides with the Claude terracotta badge.
2. **No theming.** The user wants to pick between visual themes.

**Insight:** these are the same work. Collapsing every color into **one `Palette` struct (single source of truth)** makes consistency automatic *and* makes a theme just a different `Palette` instance. This spec does both: consolidate, then ship switchable built-in themes selectable from the menu-bar dropdown and persisted.

**Success criteria:**
1. Every color the notch UI draws resolves from the active `Palette` — no raw `.blue`/`.green`/`.red`/`.orange`/`.yellow` or ad-hoc `Color(...)` literals left in the views/components (surfaces, borders, text, state accents, agent tints, diff +/−, spark, dots).
2. A **Theme ▸** submenu in the `◗` menu switches among ≥10 built-in themes; the active one shows a checkmark; the whole notch recolors **live** on selection.
3. The choice **persists** across relaunch (UserDefaults).
4. Within every theme the six session states stay visually distinguishable, and text meets a sane contrast floor over the theme's own surface.
5. Behavior is unchanged (decision wire, jump, sessions); existing 78 tests stay green.

---

## 2. Scope & non-goals

**In scope:**
- A `Palette` value type = the single source of truth for all UI colors; `Accent` demoted to a semantic *key*.
- `Theme` (id + name + Palette) and `ThemeStore` (list, current, UserDefaults persistence).
- Reactive application via SwiftUI `@Environment(\.palette)`, bridged through `NotchViewModel.palette` so switching recolors live.
- A **Theme** submenu in the existing AppKit status-bar menu (checkmark on active, same pattern as "Sound").
- Consolidation of ALL existing color usages onto the palette (the "make it consistent" work), including the bundled fixes in §6.
- **10 built-in themes** (§5).

**Non-goals (per the chosen scope):**
- **No custom color editor / Settings window.** Switching between built-ins only. (A future increment could add a color editor on top of this seam.)
- No per-surface or per-agent user overrides.
- No light-mode auto-switching / system-appearance following (a theme is chosen explicitly).
- No changes to Core, transport, hooks, decision logic, jump, or the agent/terminal seams beyond reading `agentID` (already available).

---

## 3. Users & use case

Same single-developer, MacBook-notch context. The need: the surface they stare at all day should match their taste and environment — true-black for OLED, high-contrast over bright wallpapers, or just a look they like — without editing code.

---

## 4. Locked decisions

1. **One `Palette` = single source of truth**; `Accent` becomes a color-free semantic key resolved by the palette.
2. **Switchable built-in themes** via the menu-bar **Theme ▸** submenu; **persisted** to UserDefaults; **live** recolor on switch.
3. **Reactive propagation** = `@Environment(\.palette)`, bridged by `NotchViewModel.palette` (`@Published`).
4. **Neutral card border** from `palette.border` for all kinds — the accent is carried only by the strip dot+title (fixes the "loud colored frame" + the amber/terracotta collision).
5. **Agent tints are themeable** (palette fields), not fixed brand colors — so e.g. Matrix can go green — while keeping agents distinguishable within each theme.
6. **needsInput keeps its distinct dot** via a dedicated `palette.needsInputDot` field (the deliberate dot-vs-surface split from the prior pass, now expressed in the palette).
7. **No new test cases** (repo + project policy). Guardrail = `swift build` 0 warnings + existing `swift test` 78/78 + live e2e theme-switch check.
8. **10 themes:** Graphite (default) · Midnight · High-contrast · Warm · Nord · Catppuccin (Mocha) · Tokyo Night · Dune · Matrix · Avengers.

---

## 5. The themes

Each is a full `Palette`. Character + intent (exact hex values are fixed in the implementation plan; each must keep the 6 states distinguishable and text legible over its own surface):

- **Graphite** *(default)* — the refined current look: graphite surfaces (`#131316→#0c0c0e`), Apple-system state accents (blue/green/red/amber/teal/indigo), Claude terracotta. The baseline everyone starts on.
- **Midnight** — true-black (`#000`) surfaces for OLED/deep-dark; slightly punchier accents to pop against pure black.
- **High-contrast** — accessibility: brighter text, stronger (higher-opacity) borders, more saturated accents, larger contrast ratios; best over bright wallpapers.
- **Warm** — terracotta-forward, calmer/less-rainbow palette leaning into the Claude brand; fewer competing hues.
- **Nord** — the cool blue-gray Nord palette (muted, low-saturation), recognizable and easy on the eyes.
- **Catppuccin (Mocha)** — soft pastel accents (mauve/peach/teal/green) on warm charcoal; harmonious and calm.
- **Tokyo Night** — deep navy/indigo surfaces with soft neon accents; sleek and understated.
- **Dune** — spice-orange & desert sand on near-black; warm and cinematic, pairs with the brand terracotta.
- **Matrix** — iconic green-on-black code aesthetic; neutral/brand goes green, states still vary enough to read.
- **Avengers** — Iron-Man red + gold on near-black, heroic; blue retained for "working" so states stay distinct.

---

## 6. Consistency fixes bundled in

The consolidation *is* the consistency fix, but specifically:
- **Neutral border** (decision #4): `CardContainer` uses `palette.border`, not the accent — kills the loud frame and the amber/terracotta collision.
- **Orange collision** (Graphite/Warm/Dune/Avengers): each palette gives `needsPermission` and `agentClaude` distinct hues so they don't merge on a permission card.
- **Duplicate blues/greens/reds removed**: `SessionState.dotColor` → `palette.dot(for:)`; `CountDot` colors → `palette.accent(...)`; diff `+/−` → `palette.diffAdd/diffRemove`; `✦` → `palette.spark`; notice → `palette.failed`. Exactly one value per semantic role, per theme.

---

## 7. Architecture

All new types live in the **App module** (they use SwiftUI `Color`; Core stays Foundation-only).

- **`Palette`** (`Palette.swift`) — value type with fields for surfaces (`surfaceTop`, `surfaceBottom`, `innerBox`), `border`, `textPrimary`/`textSecondary`, the state accents (`working`, `done`, `failed`, `needsPermission`, `plan`, `question`, `ended`), `needsInputDot`, agent tints (`agentClaude`, `agentCodex`, `agentGemini`, `agentFallback`), and `diffAdd`, `diffRemove`, `spark`. Resolvers: `func accent(_ Accent) -> Color`, `func softFill(_ Accent) -> Color` (= `accent(_).opacity(0.14)`), `func dot(for SessionState) -> Color` (needsInput → `needsInputDot`), `func agentTint(_ agentID: String) -> Color`.
- **`Accent`** (`NotchTheme.swift`, refactored) — stays the enum, loses its color computeds. `DecisionKind.accent` and `SessionState.surfaceAccent` unchanged (still return `Accent`).
- **`Theme`** — `{ id: String, name: String, palette: Palette }`. **`Themes`** (`Themes.swift`) — the 10 instances + `Themes.all` + `Themes.default` (Graphite).
- **`ThemeStore`** (`ThemeStore.swift`) — `ObservableObject`: `let all: [Theme]`, `@Published private(set) var current: Theme`, `func select(id:)` (updates + persists), loads persisted id on init (unknown/missing → Graphite). Persistence via `UserDefaults` key `notch.themeID`.
- **Propagation** — a `PaletteKey: EnvironmentKey` (default Graphite) + `EnvironmentValues.palette`. Notch root views (`NotchExpandedView`, `NotchCompactView`) apply `.environment(\.palette, vm.palette)`; every component reads `@Environment(\.palette) var palette`. `NotchViewModel` gains `@Published var palette: Palette = Themes.default.palette`.
- **Wiring** — `AppCoordinator` owns the `ThemeStore`, sets `vm.palette = store.current.palette` initially and whenever it changes (Combine sink or direct call from the menu action), and builds the **Theme** submenu (one item per `Themes.all`, checkmark on `store.current`, `#selector(selectTheme(_:))` carrying the theme id via `representedObject`).

**Data flow:** menu select → `ThemeStore.select(id)` → persist + publish → `AppCoordinator` sets `vm.palette` → root views re-render → `@Environment(\.palette)` updates → all components recolor.

---

## 8. Data & model touchpoints

- **No Core changes.** `Accent`, `DecisionKind.accent`, `SessionState.surfaceAccent`, `SessionState` cases, `agentID` all already exist.
- `NotchViewModel` gains `palette`. `NotchController`/`AppCoordinator` gain theme wiring. All view/component files change their color *reads* only.
- `AgentBadge.forID` splits: the **name** lookup stays (static); the **tint** now comes from `palette.agentTint(agentID)`. `AgentBadgeView` reads the palette for the tint.

---

## 9. Testing

Per repo + project policy, **no new test cases** are added on our own initiative, and there are no SwiftUI/App-module tests today. Verification per task = `swift build` (0 warnings) + existing `swift test` **78/78** (guard that Core/behavior is untouched). Final acceptance = live e2e: switch each theme from the menu and confirm the notch recolors, the choice persists across relaunch, and every state stays legible.

---

## 10. Risks & mitigations

- **Legibility per theme** — a bad palette could make text or a state unreadable over its own surface. → Each palette is authored against its own surface with a contrast floor; the live e2e checks all 10.
- **Environment not updating live** — if the injection isn't tied to an observed `@Published`, switching won't recolor. → Bridge through `vm.palette` (`@Published`), injected in the root bodies the views already observe; verify live.
- **DynamicNotchKit content caching** — the notch builds content closures once. → The closures capture the VM; recolor rides the VM's `@Published palette`, not a rebuild.
- **UserDefaults suite** — headless/`.app` differences. → Standard `UserDefaults.standard`; unknown/missing id falls back to Graphite (never crashes).
- **Scope creep toward a color editor** — fenced out in §2.

---

## 11. File-level change map

- **New:** `Sources/ClaudeNotchApp/UI/Palette.swift` (Palette struct + resolvers + `EnvironmentValues.palette`).
- **New:** `Sources/ClaudeNotchApp/UI/Themes.swift` (the 10 `Theme`/`Palette` instances + `Themes.all`/`.default`).
- **New:** `Sources/ClaudeNotchApp/UI/ThemeStore.swift` (`ObservableObject` + UserDefaults persistence).
- **Edit:** `NotchTheme.swift` — strip colors from `Accent` (keep the enum + `NotchMetric`); move agent tints out of `AgentBadge` (name-only) into the palette.
- **Edit:** `NotchComponents.swift` — all components read `@Environment(\.palette)`; `CardContainer` uses `palette.surface*` + neutral `palette.border`; `Badge`/`AgentBadgeView`/`IndexChip`/`OptionRow`/`ActionButton`/`AccentStrip`/`ActivityLine`/`SessionContextStrip` resolve via palette.
- **Edit:** `NotchViews.swift` — `NotchViewModel.palette`; root views inject `.environment(\.palette, vm.palette)`; `SessionState.dotColor`→`palette.dot(for:)`; `CountDot`, diff +/−, diffstat, `✦`, notice → palette.
- **Edit:** `NotchController.swift` — pass/observe palette as needed for the roots.
- **Edit:** `AppCoordinator.swift` — own `ThemeStore`, wire `store.current → vm.palette`, add the **Theme ▸** submenu + `selectTheme(_:)` + persistence.

---

## 12. Implementation notes

- Build subagent-driven (spec → plan → tasks); coding subagents run on **opus** (memory `coding-tasks-use-opus`).
- Sequence so each task builds cleanly: (1) `Palette` + Environment + `Accent` demotion, (2) `Themes` (Graphite first, then the rest), (3) route components onto the palette, (4) route `NotchViews` (dots/pill/diff/header) + VM bridge, (5) `ThemeStore` + persistence, (6) menu switcher + `AppCoordinator` wiring. Each ends build-clean + 78/78.
- Honesty/consistency is the point: after this, `grep -nE '\.(blue|green|red|orange|yellow|purple)\b'` over the view files should return nothing but palette definitions.
