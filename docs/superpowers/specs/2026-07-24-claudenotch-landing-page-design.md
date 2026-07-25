# ClaudeNotch — Landing Page Design (v2: interactive Next.js)

**Date:** 2026-07-24 (revised)
**Status:** Design (approved in brainstorming; supersedes the earlier static single-file approach)
**Type:** New public-facing artifact — interactive marketing landing page

> **Supersedes** the first draft of this spec (a single self-contained static `site/index.html`).
> Direction changed after review: the page should be **innovative and interactive** — it should
> *behave like the product* — and is built as a **Next.js app**, not hand-rolled static HTML.

## 1. Overview & Goal

Build one hostable, **innovative** marketing landing page for ClaudeNotch (a native macOS app that
turns the MacBook notch into a live status monitor for parallel Claude Code / Codex CLI sessions).

The signature idea: **the product is the demo.** Instead of *describing* the notch in static
sections, the hero is a live, reactive **playground** — a framed macOS "stage" where fake sessions
run, the notch updates in real time, and the visitor can act on it. It **auto-plays** a looping
cinematic demo and lets the visitor **tap in to take over** at any moment. A menu-bar **theme
switcher** recolors the entire stage *and page* live across all 10 built-in themes.

Below the playground, cleaner **scannable marketing sections** serve visitors who just want to skim
features. A prominent **"Download for macOS"** CTA is a placeholder link until a build is shipped.

### Approved decisions (brainstorming)
- **Goal / CTA:** full marketing page with a **placeholder "Download for macOS"**.
- **Concept:** **Hybrid** — interactive auto-play playground hero + scannable sections below.
- **Playground behavior:** **auto-play with tap-to-interject** (loops on its own; click to take over).
- **Stack:** **Next.js (App Router) + TypeScript + Tailwind CSS + Framer Motion**.
- **Deploy:** **standard Next.js on Vercel** (SSR/ISR/edge available if ever needed).

## 2. Non-Goals

- No backend/API, no auth, no database, no CMS — all content is static/local.
- No real download binary yet (Download is a placeholder `href`).
- No email/waitlist backend.
- No rate-limit / server-truth usage data (tokens + cost only, matching the product).
- No automated test suite added unprompted (project standard — see §12). Verification is
  typecheck + lint + `next build` + browser checks.

## 3. Tech Stack & Project Layout

- **Next.js** App Router, **TypeScript**, **Tailwind CSS**, **Framer Motion**, `next/font`
  (Instrument Serif + JetBrains Mono). Node/npm. Deploy: Vercel.
- The app lives in a **`web/`** subdirectory (the repo root is the Swift app; keep them separate).

```
web/
  package.json, next.config.mjs, tsconfig.json, tailwind.config.ts, postcss.config.mjs
  app/
    layout.tsx        # fonts, metadata/OG, <ThemeProvider>, imports globals.css
    globals.css       # Tailwind layers, :root CSS-var contract, keyframes, reduced-motion
    page.tsx          # composes the sections
  lib/
    themes.ts         # Palette type + 10 palettes (exact hex) + resolve() + PALETTES/THEME_ORDER
    theme-context.tsx # ThemeProvider + useTheme(); writes palette -> CSS vars; localStorage
    types.ts          # Session, SessionState, AgentId, TerminalId, ActKind, etc.
    useSimulatedSessions.ts # auto-play state machine + tap-to-interject controls
  components/
    stage/ Stage.tsx MenuBar.tsx Notch.tsx SessionRow.tsx TerminalWindow.tsx ActCard.tsx
    ThemeSwitcher.tsx
    sections/ Hero.tsx HowItWorks.tsx ActInPlace.tsx Capabilities.tsx AgentsTerminals.tsx
              ThemesGallery.tsx Roadmap.tsx CTA.tsx Footer.tsx Nav.tsx
    ui/ Section.tsx Badge.tsx Button.tsx Chip.tsx
```

Design units are small and single-responsibility; files that change together live together
(everything for the stage under `components/stage/`).

## 4. Visual Language

Evolves the established mockup (`docs/mockups/claudenotch-v2-preview.html`):
- **Type:** Instrument Serif for display headings (italic accent word), JetBrains Mono for
  kickers/labels/code, system `-apple-system` stack for notch/panel content.
- **Surfaces:** dark, driven by the active theme's `surfaceTop`/`surfaceBottom`; grain + scanline
  overlays (subtle).
- **Chrome accents:** numbered sections, kickers in the theme brand accent.
- **The macOS stage:** wallpaper → menubar → notch panel → terminal windows, all themed and now
  **animated** (Framer Motion) and **interactive**.
- **State system:** one accent per state; per-agent badge tints — all from the palette.

## 5. Theming

- **Source of truth:** all 10 palettes encoded in `lib/themes.ts` with the **exact hex** from
  `Sources/ClaudeNotchApp/UI/Themes.swift` + `Palette.swift`, reproducing the Swift initializer's
  derived defaults (`innerBox`=black@0.28, `border`=white@0.12, `ended`=textSecondary@0.75,
  `onAccent`=white, `agentFallback`=textSecondary, `diffAdd`=done, `diffRemove`=failed,
  `spark`=needsInputDot). Themes: Graphite (default), Midnight, High Contrast, Warm, Nord,
  Catppuccin, Tokyo Night, Dune, Matrix, Avengers.
- **Application:** `ThemeProvider` writes the resolved palette to **CSS custom properties** on the
  document root; **Tailwind** `theme.extend.colors` map to those `var(--…)` so utility classes are
  themed. Changing theme rewrites the vars → the whole page + stage recolor. Primary-button text
  uses `--on-accent` (readable on light themes). Persisted to `localStorage` (`claudenotch.theme`),
  default Graphite. Cross-fade via CSS transition / Framer Motion; instant under reduced-motion.
- **Two entry points:** the in-stage **menu-bar Theme control** (primary, product-authentic) and a
  full **Themes gallery** section (10 selectable mini-notch cards). Both stay in sync via context.

## 6. The Playground (hero) — behavior

- **Auto-play:** on load, a looping scripted timeline runs: sessions spawn, progress through states
  (working → needs permission → resolve → done), the notch expands to show act-in-place cards, rows
  reflow (Framer Motion `layout`), dots pulse. It tells the whole story hands-free.
- **Tap-to-interject:** any click/keypress in the stage pauses auto-play and hands control to the
  visitor; a subtle "you're driving — ▶ resume demo" affordance lets them return to auto-play.
- **Visitor actions when driving:**
  - Act on a decision card: **Allow / Deny / Allow for session** (permission), pick an **option**
    (ask), **Approve / Request changes** (plan) → card resolves, session continues.
  - **Click a session row** → the matching **terminal window** focuses/flashes ("jump to pane").
  - **Menu-bar Theme switch** → live recolor.
  - (Optional) **Spawn a session** control.
- **Reduced-motion:** auto-play does not animate; it presents a representative static composition;
  interactions still work but transitions are instant.
- **State engine:** `useSimulatedSessions` is a self-contained reducer/hook (spawn, tick,
  transition, resolve, pause/resume). No network. It is the correctness-critical seam.

## 7. Page Structure

1. **Sticky nav** — wordmark · Features / Act in place / Themes / Roadmap · Download.
2. **Hero = the playground** (§6) + headline/subhead + Download (placeholder) + "See it in action".
3. **How it works** — hooks → `notch-bridge` → localhost → notch → click-to-jump. "No yabai, no
   cloud, no telemetry."
4. **Act in place** — the trio (permission diff / ask / plan), interactive, reusing `ActCard`.
5. **Everything it does** — full capability inventory grid (§7.1).
6. **Many agents, many terminals** — Claude ✓ / Codex ✓ / Gemini (planned); iTerm2 ✓ / WezTerm ✓ /
   Kitty ✓ / others raise-to-front; `AgentProvider` / `TerminalJumper` seams noted.
7. **Themes** — interactive 10-theme gallery.
8. **Roadmap** — SSH remote / mobile relay / cost & limits (later/exploring).
9. **Final CTA band** — Download (placeholder) + requirements (Apple Silicon · macOS 14+ ·
   iTerm2/WezTerm/Kitty · Claude Code).
10. **Footer** — local-only, no cloud/telemetry, DynamicNotchKit credit, honesty note.

### 7.1 Capability inventory
Glanceable multi-session monitor (5 states) · precise click-to-jump · act-in-place decisions
(permission incl. allow-for-session, AskUserQuestion, plan) · rich glance rows (agent+terminal
badges, activity, elapsed) · usage & cost (tokens + $) · completion sounds (Glass/Basso/Funk,
toggleable) · 10 live themes · multi-agent (Claude + Codex; Gemini planned) via `AgentProvider` ·
multi-terminal jump (iTerm2/WezTerm/Kitty; others raise-to-front) via `TerminalJumper` ·
self-configuring hooks (with settings backup) · private/local-only (no cloud/telemetry/yabai) ·
hover-expand rows.

## 8. Accuracy / Honesty Rules

Confident present tense for shipped features. Truthful exceptions: **Gemini = planned**; **roadmap =
future**; **Download = placeholder** (disclosed in footer); usage = **tokens + cost only**;
terminal support distinguishes **precise-jump (iTerm2/WezTerm/Kitty)** from **raise-to-front**;
Ask option numbering is a visual index, not keyboard shortcuts.

## 9. Motion & Accessibility

- All motion via Framer Motion respects `useReducedMotion()` / `prefers-reduced-motion` → instant,
  auto-play stops animating.
- Interactive elements are real buttons/focusable with visible focus (`:focus-visible`);
  `aria-pressed` on theme controls; semantic landmarks; meaningful labels.
- Contrast held by each palette's own text/surface pairing.

## 10. Responsive

Fluid `clamp()` type; ≤900px grids collapse; the stage scales down and remains legible/tappable on
touch; nav condenses.

## 11. Deliverables

The `web/` Next.js app (all files in §3) + `web/README.md` (dev + Vercel deploy notes). The obsolete
`site/` static scaffold from the superseded approach is removed.

## 12. Verification Plan

- **Palette fidelity:** all 10 palettes in `lib/themes.ts` match the Swift hex (§5) + derived defaults.
- **Theming:** theme switch (menu-bar + gallery) rewrites CSS vars, recolors page + stage, persists.
- **Playground:** auto-play loops; tap-to-interject pauses + hands over; act cards resolve; row
  click focuses the terminal.
- **Build hygiene:** `tsc --noEmit` clean, ESLint clean, `next build` succeeds.
- **A11y:** reduced-motion disables animation; keyboard focus reaches controls.
- **Live visual e2e:** human-pending (project pattern). No automated test suite added unless the
  user asks; optional Vitest units for the theme resolver + session reducer are available on request.

## 13. Open Questions

None blocking. Defaults: app in `web/`, brand accent = `agentClaude`, default theme Graphite,
standard Next.js/Vercel build.
