# ClaudeNotch Landing Page Implementation Plan (v2: interactive Next.js)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Supersedes** the earlier static single-file plan. Approach changed to an interactive Next.js app after design review. The obsolete `site/` scaffold is removed in Task 1.

**Goal:** Build an innovative, interactive marketing landing page for ClaudeNotch as a Next.js app: a hero "playground" where a simulated macOS notch auto-plays a live demo and the visitor can tap in to take over, plus a live 10-theme switcher that recolors the whole page, and scannable marketing sections below.

**Architecture:** Next.js 16 App Router + TypeScript + Tailwind CSS v4 + Motion (`motion` package). A single landing route (`app/page.tsx`) composes sections. Theming is driven by CSS custom properties written by a React context (`ThemeProvider`) and mapped into Tailwind v4 via `@theme inline`, so switching a theme rewrites the vars and recolors everything. A self-contained `useSimulatedSessions` hook is a reducer-based state machine that auto-plays a scripted timeline and accepts visitor interjection. Lives in a `web/` subdirectory (repo root is the Swift app).

**Tech Stack:** Next.js 16 (App Router, Turbopack), TypeScript, Tailwind CSS v4, `motion` (Framer Motion for React), `next/font/google` (Instrument Serif + JetBrains Mono). Deploy: Vercel.

## Global Constraints

- **App location:** everything under `web/` (a Next.js app). Repo root stays the Swift package.
- **Deploy target:** standard Next.js on Vercel (do NOT configure static export).
- **Stack:** App Router + TS + Tailwind v4 + `motion`. No other UI/animation deps unless a task says so.
- **Palette fidelity:** the 10 palettes in `web/lib/themes.ts` MUST match `Sources/ClaudeNotchApp/UI/Themes.swift` + `Palette.swift` exactly (hex in Task 2). Derived defaults: `innerBox`=black@0.28, `border`=white@0.12, `ended`=textSecondary@0.75, `onAccent`=white, `agentFallback`=textSecondary, `diffAdd`=done, `diffRemove`=failed, `spark`=needsInputDot.
- **Default theme:** Graphite. Persisted to `localStorage` key `claudenotch.theme`. Brand accent (`--accent`) = the theme's `agentClaude`. Primary-button text uses `--on-accent`.
- **Fonts:** Instrument Serif (display headings, italic accent word), JetBrains Mono (kickers/labels/code), system `-apple-system` stack for notch/panel content. Load Google fonts via `next/font/google` with the `variable` option; expose as `--font-serif`, `--font-mono`.
- **Motion:** import from `motion/react`. Every animation respects `useReducedMotion()` — reduced ⇒ instant, and auto-play stops animating.
- **Accuracy (spec §8):** Gemini = planned; Download = placeholder `href`; usage = tokens + cost only (no rate-limit windows); iTerm2/WezTerm/Kitty = precise jump, others = raise-to-front; Ask option numbers = visual index (not keyboard shortcuts). Confident present tense for shipped features.
- **A11y:** semantic landmarks; real focusable `<button>`/`<a>`; visible `:focus-visible`; `aria-pressed` on theme controls.
- **Testing:** Do NOT add an automated test suite (project standard). Verification per task = `npx tsc --noEmit` clean + `npm run lint` clean + `npm run build` succeeds + the named browser checks. (Optional Vitest units for the theme resolver + session reducer only if the user later asks.)
- **Visual reference to adapt:** `docs/mockups/claudenotch-v2-preview.html` — match its craft (dark aesthetic, Instrument Serif + JetBrains Mono, terracotta-family accent, macOS stage, accent-per-state, per-agent badge tints), retheming its hardcoded colors onto the CSS variables.
- **Commits:** Conventional Commits, NO JIRA prefix (repo convention, local-only). All commands run from `web/` unless noted. Every commit body ends with the trailer:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

---

## File Structure

```
web/
  package.json  next.config.ts  tsconfig.json  postcss.config.mjs  eslint.config.mjs
  app/
    layout.tsx        # fonts + metadata/OG + <ThemeProvider>; imports globals.css
    globals.css       # @import "tailwindcss"; :root palette var contract (Graphite);
                      # @theme inline mapping; keyframes; reduced-motion
    page.tsx          # <Nav/> + sections in order
  lib/
    themes.ts         # Palette type, RAW 10 palettes (exact hex), resolve(), PALETTES, THEME_ORDER
    theme-context.tsx # "use client" ThemeProvider + useTheme(); writes CSS vars; localStorage
    types.ts          # Session, SessionState, ActKind, AgentId, TerminalId, etc.
    useSimulatedSessions.ts # "use client" auto-play reducer/hook + interject controls
  components/
    stage/ Stage.tsx MenuBar.tsx Notch.tsx SessionRow.tsx TerminalWindow.tsx ActCard.tsx
    ThemeSwitcher.tsx
    sections/ Hero.tsx HowItWorks.tsx ActInPlace.tsx Capabilities.tsx AgentsTerminals.tsx
              ThemesGallery.tsx Roadmap.tsx CTA.tsx Footer.tsx Nav.tsx
    ui/ Section.tsx Badge.tsx Button.tsx Chip.tsx
  README.md
```

Each task appends focused files and ends with a build + browser check + commit. Interactive components carry `"use client"`; sections that are static stay server components.

---

## Task 1: Scaffold the Next.js app + fonts + theming CSS base

**Files:**
- Create: the `web/` app via `create-next-app`; then edit `web/app/layout.tsx`, `web/app/globals.css`, `web/app/page.tsx`.
- Remove: `site/` (obsolete scaffold from the superseded approach).

**Interfaces:**
- Produces: the `web/` app; `--font-serif`/`--font-mono` CSS vars; the `:root` palette variable contract (Graphite fallback) + `@theme inline` color tokens every later task uses (`--surface-top`, `--surface-bottom`, `--inner-box`, `--border`, `--text-primary`, `--text-secondary`, `--on-accent`, `--st-working`, `--st-done`, `--st-failed`, `--st-perm`, `--st-plan`, `--st-ask`, `--st-ended`, `--needs-input-dot`, `--ag-claude`, `--ag-codex`, `--ag-gemini`, `--accent`).

- [ ] **Step 1: Remove the obsolete static scaffold**

```bash
cd /Users/navjotdhanawat/Workspace/claude-notch
git rm -r site
```

- [ ] **Step 2: Scaffold the app (non-interactive)**

```bash
cd /Users/navjotdhanawat/Workspace/claude-notch
npx create-next-app@latest web --ts --tailwind --eslint --app --no-src-dir --import-alias "@/*" --use-npm --yes
cd web && npm install motion
```
Expected: `web/` created with App Router + Tailwind v4 + TS; `motion` added to dependencies. If `create-next-app` also writes `web/AGENTS.md`, leave it.

- [ ] **Step 3: Load the two fonts in `app/layout.tsx`**

Replace the default fonts with Instrument Serif + JetBrains Mono exposed as CSS variables, and set base metadata:

```tsx
import type { Metadata } from "next";
import { Instrument_Serif, JetBrains_Mono } from "next/font/google";
import { ThemeProvider } from "@/lib/theme-context"; // added in Task 2; placeholder-safe here
import "./globals.css";

const serif = Instrument_Serif({ subsets: ["latin"], weight: "400", style: ["normal","italic"], variable: "--font-serif", display: "swap" });
const mono = JetBrains_Mono({ subsets: ["latin"], variable: "--font-mono", display: "swap" });

export const metadata: Metadata = {
  title: "ClaudeNotch — a live monitor for your Claude Code sessions",
  description: "Turn your MacBook notch into mission control for parallel Claude Code & Codex sessions: glance, jump to the exact pane, and decide in place. 10 themes.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${serif.variable} ${mono.variable}`}>
      <body>{children}</body>
    </html>
  );
}
```
NOTE: `ThemeProvider` is created in Task 2. For THIS task, do not import it yet — leave `<body>{children}</body>` without the provider so the build passes. (Task 2 adds the import + wrap.)

- [ ] **Step 4: Write `app/globals.css` — Tailwind v4 + palette var contract (Graphite)**

```css
@import "tailwindcss";

:root{
  /* palette (Graphite fallback; ThemeProvider overwrites at runtime) */
  --surface-top:#131316; --surface-bottom:#0C0C0E;
  --inner-box:rgba(0,0,0,.28); --border:rgba(255,255,255,.12);
  --text-primary:#ECEAE4; --text-secondary:#8B8B93; --on-accent:#ffffff;
  --st-working:#0A84FF; --st-done:#30D158; --st-failed:#FF453A;
  --st-perm:#FF9F0A; --st-plan:#A78BFA; --st-ask:#5AC8FA; --st-ended:rgba(139,139,147,.75);
  --needs-input-dot:#FFD60A;
  --ag-claude:#E39178; --ag-codex:#5FD0B0; --ag-gemini:#8FB0F9;
  --accent:#E39178;
}

/* Expose palette + fonts to Tailwind utilities (bg-surface-top, text-accent, font-serif, …) */
@theme inline{
  --color-surface-top:var(--surface-top);
  --color-surface-bottom:var(--surface-bottom);
  --color-inner-box:var(--inner-box);
  --color-border-c:var(--border);
  --color-text-primary:var(--text-primary);
  --color-text-secondary:var(--text-secondary);
  --color-on-accent:var(--on-accent);
  --color-st-working:var(--st-working);
  --color-st-done:var(--st-done);
  --color-st-failed:var(--st-failed);
  --color-st-perm:var(--st-perm);
  --color-st-plan:var(--st-plan);
  --color-st-ask:var(--st-ask);
  --color-st-ended:var(--st-ended);
  --color-needs-input-dot:var(--needs-input-dot);
  --color-ag-claude:var(--ag-claude);
  --color-ag-codex:var(--ag-codex);
  --color-ag-gemini:var(--ag-gemini);
  --color-accent:var(--accent);
  --font-serif:var(--font-serif);
  --font-mono:var(--font-mono);
}

body{
  background:linear-gradient(180deg,var(--surface-top),var(--surface-bottom)) fixed;
  color:var(--text-primary);
  font-family:var(--font-mono),ui-monospace,"SF Mono",Menlo,monospace;
  -webkit-font-smoothing:antialiased;
  transition:background .25s ease,color .25s ease;
}

@media (prefers-reduced-motion: reduce){
  *{animation:none !important; transition:none !important}
}
```

- [ ] **Step 5: Minimal `app/page.tsx`**

```tsx
export default function Home() {
  return (
    <main className="mx-auto max-w-[1180px] px-6 py-24">
      <h1 style={{ fontFamily: "var(--font-serif)" }} className="text-6xl">
        Claude<em className="text-accent not-italic">Notch</em>
      </h1>
      <p className="mt-4 text-text-secondary">Scaffold OK — sections land in later tasks.</p>
    </main>
  );
}
```

- [ ] **Step 6: Verify build + dev render**

```bash
cd web
npx tsc --noEmit && npm run lint && npm run build
```
Expected: typecheck clean, lint clean, build succeeds. Then `npm run dev` and open http://localhost:3000 — dark Graphite background, serif "ClaudeNotch" with a terracotta "Notch". Confirm the two fonts load (DevTools → Network → fonts). Confirm `site/` is gone: `ls ../site` → "No such file or directory".

- [ ] **Step 7: Commit**

```bash
cd /Users/navjotdhanawat/Workspace/claude-notch
git add web && git rm -r --cached site 2>/dev/null; git add -A
git commit -m "$(printf 'feat: scaffold Next.js landing app + fonts + theming CSS base\n\nRemoves the superseded static site/ scaffold.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 2: Theme system — palettes, resolver, provider (live CSS-var theming)

**Files:**
- Create: `web/lib/themes.ts`, `web/lib/theme-context.tsx`
- Modify: `web/app/layout.tsx` (wrap children in `<ThemeProvider>`), `web/app/page.tsx` (temporary theme buttons to verify)

**Interfaces:**
- Produces: `Palette` type; `PALETTES: Record<ThemeId, Palette>`; `THEME_ORDER: ThemeId[]`; `ThemeId`; `<ThemeProvider>`; `useTheme(): { themeId, setTheme, palette }`.
- Consumes: the CSS-var names from Task 1.

- [ ] **Step 1: `lib/themes.ts` — types + all 10 palettes (exact hex) + resolver**

Transcribe ALL 10 palettes exactly (do not abbreviate). Core hues only; the resolver fills derived defaults.

```ts
export type ThemeId =
  | "graphite" | "midnight" | "high-contrast" | "warm" | "nord"
  | "catppuccin" | "tokyo-night" | "dune" | "matrix" | "avengers";

export interface Palette {
  name: string;
  surfaceTop: string; surfaceBottom: string; innerBox: string; border: string;
  textPrimary: string; textSecondary: string; onAccent: string;
  working: string; done: string; failed: string;
  needsPermission: string; plan: string; question: string; ended: string;
  needsInputDot: string;
  agentClaude: string; agentCodex: string; agentGemini: string;
  accent: string; // = agentClaude (brand accent)
}

const rgba = (hex: string, a: number) => {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
};

type Raw = {
  name: string; surfaceTop: string; surfaceBottom: string;
  textPrimary: string; textSecondary: string;
  working: string; done: string; failed: string;
  needsPermission: string; plan: string; question: string; needsInputDot: string;
  agentClaude: string; agentCodex: string; agentGemini: string;
  innerBox?: string; border?: string; ended?: string; onAccent?: string;
};

const RAW: Record<ThemeId, Raw> = {
  graphite:{name:"Graphite",surfaceTop:"#131316",surfaceBottom:"#0C0C0E",textPrimary:"#ECEAE4",textSecondary:"#8B8B93",working:"#0A84FF",done:"#30D158",failed:"#FF453A",needsPermission:"#FF9F0A",plan:"#A78BFA",question:"#5AC8FA",needsInputDot:"#FFD60A",agentClaude:"#E39178",agentCodex:"#5FD0B0",agentGemini:"#8FB0F9"},
  midnight:{name:"Midnight",surfaceTop:"#050506",surfaceBottom:"#000000",textPrimary:"#F2F2F5",textSecondary:"#8E8E96",working:"#2E9BFF",done:"#3BE06A",failed:"#FF5A50",needsPermission:"#FFB020",plan:"#B79CFF",question:"#66D0FF",needsInputDot:"#FFDE38",agentClaude:"#F0A085",agentCodex:"#5FE0C0",agentGemini:"#9CBBFF",innerBox:"#000000",border:rgba("#FFFFFF",.14)},
  "high-contrast":{name:"High Contrast",surfaceTop:"#0A0A0C",surfaceBottom:"#000000",textPrimary:"#FFFFFF",textSecondary:"#C7C7CE",working:"#339CFF",done:"#34E06A",failed:"#FF4136",needsPermission:"#FFB000",plan:"#B899FF",question:"#4EC8FF",needsInputDot:"#FFE000",agentClaude:"#FFA98C",agentCodex:"#57E7C4",agentGemini:"#9FC0FF",innerBox:"#000000",border:rgba("#FFFFFF",.30)},
  warm:{name:"Warm",surfaceTop:"#16110F",surfaceBottom:"#0D0A09",textPrimary:"#F1E8E2",textSecondary:"#A89A92",working:"#6FB0A6",done:"#86C08A",failed:"#E0685C",needsPermission:"#E8A85E",plan:"#B79CC9",question:"#7FB8C9",needsInputDot:"#E9C46A",agentClaude:"#E39178",agentCodex:"#9CC2A0",agentGemini:"#A9B8D6"},
  nord:{name:"Nord",surfaceTop:"#3B4252",surfaceBottom:"#2E3440",textPrimary:"#ECEFF4",textSecondary:"#A6ADBB",working:"#81A1C1",done:"#A3BE8C",failed:"#BF616A",needsPermission:"#D08770",plan:"#B48EAD",question:"#88C0D0",needsInputDot:"#EBCB8B",agentClaude:"#EBCB8B",agentCodex:"#8FBCBB",agentGemini:"#81A1C1",innerBox:"#292E39",border:"#4C566A",ended:"#4C566A"},
  catppuccin:{name:"Catppuccin",surfaceTop:"#1E1E2E",surfaceBottom:"#181825",textPrimary:"#CDD6F4",textSecondary:"#A6ADC8",working:"#89B4FA",done:"#A6E3A1",failed:"#F38BA8",needsPermission:"#FAB387",plan:"#CBA6F7",question:"#94E2D5",needsInputDot:"#F9E2AF",agentClaude:"#F5E0DC",agentCodex:"#74C7EC",agentGemini:"#B4BEFE",innerBox:"#11111B",border:"#313244",ended:"#6C7086",onAccent:"#0E0E11"},
  "tokyo-night":{name:"Tokyo Night",surfaceTop:"#1A1B26",surfaceBottom:"#16161E",textPrimary:"#C0CAF5",textSecondary:"#9AA5CE",working:"#7AA2F7",done:"#9ECE6A",failed:"#F7768E",needsPermission:"#FF9E64",plan:"#BB9AF7",question:"#7DCFFF",needsInputDot:"#E0AF68",agentClaude:"#F7768E",agentCodex:"#73DACA",agentGemini:"#7AA2F7",innerBox:"#101014",border:"#292E42",ended:"#565F89",onAccent:"#0E0E11"},
  dune:{name:"Dune",surfaceTop:"#14100C",surfaceBottom:"#0B0906",textPrimary:"#EDE0CF",textSecondary:"#B8A488",working:"#5AA0C4",done:"#A3B565",failed:"#C0392B",needsPermission:"#E8873A",plan:"#9B7BB0",question:"#6FB2A6",needsInputDot:"#E3B23C",agentClaude:"#B5895F",agentCodex:"#8FB56A",agentGemini:"#6FA3C4",innerBox:"#0A0705"},
  matrix:{name:"Matrix",surfaceTop:"#030503",surfaceBottom:"#000000",textPrimary:"#B9FFB9",textSecondary:"#5FA85F",working:"#39FF14",done:"#00E676",failed:"#FF3B30",needsPermission:"#FFD400",plan:"#7CFFB0",question:"#00FFC8",needsInputDot:"#EEFF41",agentClaude:"#00E676",agentCodex:"#39FF14",agentGemini:"#7CFFB0",innerBox:"#000000",border:rgba("#00FF41",.22),ended:"#2E7D32",onAccent:"#0E0E11"},
  avengers:{name:"Avengers",surfaceTop:"#0E0B0B",surfaceBottom:"#050303",textPrimary:"#F5EFE6",textSecondary:"#B9A98F",working:"#3B82F6",done:"#2FBF71",failed:"#E23636",needsPermission:"#E6A817",plan:"#7C5CFF",question:"#22B8CF",needsInputDot:"#F5C518",agentClaude:"#E6564B",agentCodex:"#22B8CF",agentGemini:"#3B82F6",innerBox:"#080505"},
};

export const THEME_ORDER: ThemeId[] = ["graphite","midnight","high-contrast","warm","nord","catppuccin","tokyo-night","dune","matrix","avengers"];

function resolve(r: Raw): Palette {
  return {
    name:r.name, surfaceTop:r.surfaceTop, surfaceBottom:r.surfaceBottom,
    innerBox:r.innerBox ?? rgba("#000000",.28),
    border:r.border ?? rgba("#FFFFFF",.12),
    textPrimary:r.textPrimary, textSecondary:r.textSecondary,
    onAccent:r.onAccent ?? "#ffffff",
    working:r.working, done:r.done, failed:r.failed,
    needsPermission:r.needsPermission, plan:r.plan, question:r.question,
    ended:r.ended ?? rgba(r.textSecondary,.75),
    needsInputDot:r.needsInputDot,
    agentClaude:r.agentClaude, agentCodex:r.agentCodex, agentGemini:r.agentGemini,
    accent:r.agentClaude,
  };
}

export const PALETTES: Record<ThemeId, Palette> =
  Object.fromEntries(THEME_ORDER.map(id => [id, resolve(RAW[id])])) as Record<ThemeId, Palette>;

/** Map a palette to the CSS custom properties defined in globals.css. */
export function paletteVars(p: Palette): Record<string, string> {
  return {
    "--surface-top":p.surfaceTop, "--surface-bottom":p.surfaceBottom,
    "--inner-box":p.innerBox, "--border":p.border,
    "--text-primary":p.textPrimary, "--text-secondary":p.textSecondary, "--on-accent":p.onAccent,
    "--st-working":p.working, "--st-done":p.done, "--st-failed":p.failed,
    "--st-perm":p.needsPermission, "--st-plan":p.plan, "--st-ask":p.question, "--st-ended":p.ended,
    "--needs-input-dot":p.needsInputDot,
    "--ag-claude":p.agentClaude, "--ag-codex":p.agentCodex, "--ag-gemini":p.agentGemini,
    "--accent":p.accent,
  };
}
```

- [ ] **Step 2: `lib/theme-context.tsx` — provider + hook**

```tsx
"use client";
import { createContext, useContext, useEffect, useState, useCallback } from "react";
import { PALETTES, paletteVars, type ThemeId, type Palette } from "@/lib/themes";

const KEY = "claudenotch.theme";
type Ctx = { themeId: ThemeId; palette: Palette; setTheme: (id: ThemeId) => void };
const ThemeCtx = createContext<Ctx | null>(null);

function applyVars(id: ThemeId) {
  const vars = paletteVars(PALETTES[id]);
  const root = document.documentElement;
  for (const k in vars) root.style.setProperty(k, vars[k]);
  root.dataset.theme = id;
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [themeId, setThemeId] = useState<ThemeId>("graphite");
  useEffect(() => {
    const saved = (typeof localStorage !== "undefined" && localStorage.getItem(KEY)) as ThemeId | null;
    const id = saved && PALETTES[saved] ? saved : "graphite";
    setThemeId(id); applyVars(id);
  }, []);
  const setTheme = useCallback((id: ThemeId) => {
    setThemeId(id); applyVars(id);
    try { localStorage.setItem(KEY, id); } catch {}
  }, []);
  return <ThemeCtx.Provider value={{ themeId, palette: PALETTES[themeId], setTheme }}>{children}</ThemeCtx.Provider>;
}

export function useTheme() {
  const c = useContext(ThemeCtx);
  if (!c) throw new Error("useTheme must be used within ThemeProvider");
  return c;
}
```

- [ ] **Step 3: Wrap the app + add temporary verify buttons**

In `app/layout.tsx`, import `ThemeProvider` and wrap: `<body><ThemeProvider>{children}</ThemeProvider></body>`.
In `app/page.tsx`, add a temporary client subcomponent with buttons for a few themes (Graphite/Matrix/Nord/Avengers) calling `setTheme`, to verify live recolor. (Removed/replaced in later tasks.)

- [ ] **Step 4: Verify**

```bash
cd web && npx tsc --noEmit && npm run lint && npm run build
```
Expected: all clean. `npm run dev` → click "Matrix" → whole page background/text/accent recolor to Matrix; "Nord" → slate; reload → persists (Graphite by default). In DevTools, `getComputedStyle(document.documentElement).getPropertyValue('--surface-top')` reflects the active theme.

- [ ] **Step 5: Cross-check hex fidelity vs Swift source**

```bash
cd /Users/navjotdhanawat/Workspace/claude-notch
for h in 131316 050506 0A0A0C 16110F 3B4252 1E1E2E 1A1B26 14100C 030503 0E0B0B; do
  echo -n "#$h  swift:"; grep -ric "0x$h" Sources/ClaudeNotchApp/UI/Themes.swift Sources/ClaudeNotchApp/UI/Palette.swift | paste -sd+ - | bc; \
  echo -n "         web:"; grep -ic "\"#$h\"" web/lib/themes.ts; done
```
Expected: each surfaceTop appears in both the Swift sources and `themes.ts` (Graphite `#131316` lives in `Palette.swift`).

- [ ] **Step 6: Commit**

```bash
cd /Users/navjotdhanawat/Workspace/claude-notch
git add web && git commit -m "$(printf 'feat: theme system (10 palettes, resolver, provider, live CSS-var theming)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 3: Types + simulated-session engine (auto-play + interject)

**Files:**
- Create: `web/lib/types.ts`, `web/lib/useSimulatedSessions.ts`

**Interfaces:**
- Produces:
  - `types.ts`: `type SessionState = "working" | "needsPermission" | "needsInput" | "done" | "failed"`; `type ActKind = "permission" | "ask" | "plan"`; `type AgentId = "claude" | "codex" | "gemini"`; `interface Session { id: string; title: string; agent: AgentId; terminal: string; state: SessionState; activity: string; elapsedMin: number; act?: ActPrompt }`; `interface ActPrompt { kind: ActKind; ... }` (fields the ActCard needs — tool+diff for permission, question+options for ask, steps for plan); a small `SEED_SESSIONS` fixture.
  - `useSimulatedSessions.ts`: `useSimulatedSessions(): { sessions: Session[]; driving: boolean; autoplay: boolean; interject(): void; resume(): void; resolveAct(id: string, choice: string): void; jump(id: string): string; spawn(): void }`.
- Consumes: nothing (pure logic + timers).

- [ ] **Step 1: `lib/types.ts`**

Define the types above with concrete fields. Include `SEED_SESSIONS` (3–4 sessions covering Claude/Codex/Gemini, iTerm/Terminal/Ghostty, spanning working/needsPermission/done) and `ACT_FIXTURES` (a permission Edit diff on `src/auth/middleware.ts` (+3/−1), an ask "Which deployment target?" with Production/Staging/Local only, a plan with 4 visible steps + "+2 more"). Keep copy accurate (spec §8).

- [ ] **Step 2: `lib/useSimulatedSessions.ts` — the state machine**

Requirements (implement as a reducer + `useEffect` timer; `"use client"`):
- On mount, seed from `SEED_SESSIONS` and start **auto-play**: a `setInterval` (~2.2s; store id in a ref; clear on unmount) advances a scripted timeline — e.g. tick transitions: a working session → `needsPermission` (attaches an `act`), then after a couple ticks auto-resolves and returns to `working`/`done`, dots/activity update; occasionally spawns/retires a session so it feels alive. Keep the script deterministic and looping.
- `interject()` sets `driving=true`, `autoplay=false`, and **pauses** the auto timeline (clear the interval). Call it on the first visitor interaction.
- `resume()` sets `driving=false`, `autoplay=true`, restarts the timeline.
- `resolveAct(id, choice)` clears that session's `act` and advances its state (permission Allow/Deny → working/failed appropriately; ask → working with chosen option noted; plan Approve → working, Request changes → needsInput). Only meaningful while driving (but safe anytime).
- `jump(id)` returns a label like `"iTerm2 · <title>"` (no side effects; the Stage uses it for the toast/flash).
- `spawn()` appends a new working session with a rotating title/agent/terminal.
- **Reduced motion:** expose the data statically; the Stage decides whether to animate. The hook must not crash if `window`/timers unavailable during SSR — guard timer setup in `useEffect` (client-only).

- [ ] **Step 3: Verify (temporary debug render)**

Temporarily render `JSON.stringify(sessions)` (or a simple list) in `page.tsx` behind the theme buttons.

```bash
cd web && npx tsc --noEmit && npm run lint && npm run build
```
Expected: clean. `npm run dev` → the list updates every ~2s (auto-play); clicking a temporary "interject" button freezes updates; "resume" restarts them. No SSR/hydration errors in console.

- [ ] **Step 4: Commit**

```bash
cd /Users/navjotdhanawat/Workspace/claude-notch
git add web && git commit -m "$(printf 'feat: simulated-session engine (auto-play timeline + interject controls)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 4: Stage presentational components — Notch, SessionRow, MenuBar, TerminalWindow

**Files:**
- Create: `web/components/stage/Notch.tsx`, `SessionRow.tsx`, `MenuBar.tsx`, `TerminalWindow.tsx`; `web/components/ui/Badge.tsx`

**Interfaces:**
- Consumes: `Session`/`SessionState` types; palette CSS vars/Tailwind tokens.
- Produces:
  - `SessionRow({ session, compact, onJump })` — themed row: state dot (`bg-st-*`, pulse when working via `motion` + `useReducedMotion`), title, activity line, agent+terminal `Badge`s, elapsed. Clickable (calls `onJump`), keyboard-focusable, hover highlight, `layout` for reflow.
  - `Notch({ sessions, usage, children, onJump })` — the notch panel: rounded-bottom black panel, a usage header ("N active · tok · $"), the list of `SessionRow`s (Motion `AnimatePresence` + `layout`), and an optional `children` slot for an act card overlay.
  - `MenuBar({ right })` — mac menubar strip with app menus on the left and a `right` slot (clock + the ThemeSwitcher goes here in Task 7).
  - `TerminalWindow({ title, lines, focused })` — a terminal window with traffic lights, title, sample body; `focused` triggers a brief highlight (used by "jump").
  - `Badge({ kind, children })` — agent-tinted (`text-ag-claude` etc.) / neutral chip.
- Adapt visuals from mockup lines 105–171, 343–347 (retheme to tokens). All are `"use client"` where they use motion/hover.

- [ ] **Step 1: Build the components** per the interfaces above, using Tailwind tokens (`bg-inner-box`, `text-text-primary`, `border-border-c`, `bg-st-working`, `text-ag-claude`, `font-serif`, `font-mono`) and `motion/react` for the pulse + `layout`.

- [ ] **Step 2: Verify (temporary harness)**

Temporarily render a `Notch` fed by `useSimulatedSessions()` inside a `MenuBar` + one `TerminalWindow` in `page.tsx`.

```bash
cd web && npx tsc --noEmit && npm run lint && npm run build
```
Expected: clean. `npm run dev` → notch shows session rows that update with auto-play; working dot pulses; hovering a row highlights; rows reflow smoothly when state changes; theme switch recolors all of it.

- [ ] **Step 3: Commit**

```bash
cd /Users/navjotdhanawat/Workspace/claude-notch
git add web && git commit -m "$(printf 'feat: stage components (notch, session row, menubar, terminal, badge)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 5: ActCard — permission / ask / plan (functional, animated)

**Files:**
- Create: `web/components/stage/ActCard.tsx`

**Interfaces:**
- Consumes: `ActPrompt`/`ActKind` types; `resolveAct` from the engine; palette tokens.
- Produces: `ActCard({ prompt, session, onResolve })` where `onResolve(choice: string)` is called with the picked action; renders inside the `Notch` children slot. Three layouts:
  - **permission:** context strip (project · agent · terminal), tool + file, a diff (`add` → `st-done` tint, `del` → `st-failed` tint, +/− stat), buttons Deny / Allow / (row 2) Allow for this session.
  - **ask:** "Claude asks" + question + numbered clickable option rows (number = visual index; tinted `st-ask`).
  - **plan:** "Plan ready" + step list + "+N more" + Request changes / Approve plan.
  - Enter/exit via `motion` `AnimatePresence` (fade+scale; instant under reduced motion). Buttons are real `<button>`s; primary uses `bg-accent text-on-accent`.
- Adapt visuals from mockup lines 173–226, 356–443 (retheme to tokens).

- [ ] **Step 1: Build `ActCard`** with the three variants and wire buttons/options to call `onResolve(choice)`.

- [ ] **Step 2: Verify (temporary)**

Temporarily force a session's `act` (e.g. seed one with a permission prompt) and render the card in the notch.

```bash
cd web && npx tsc --noEmit && npm run lint && npm run build
```
Expected: clean. `npm run dev` → the card appears in the notch; clicking Allow/Deny/option/Approve calls `onResolve`, the card animates out, and the session advances (via `resolveAct`). Theme recolors the card.

- [ ] **Step 3: Commit**

```bash
cd /Users/navjotdhanawat/Workspace/claude-notch
git add web && git commit -m "$(printf 'feat: interactive act-in-place card (permission/ask/plan)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 6: Stage assembly + Hero (auto-play + tap-to-interject + jump)

**Files:**
- Create: `web/components/stage/Stage.tsx`, `web/components/sections/Hero.tsx`, `web/components/ui/Button.tsx`
- Modify: `web/app/page.tsx` (render `<Hero/>`; remove temporary harness/debug)

**Interfaces:**
- Consumes: `useSimulatedSessions`, all stage components, `useTheme`.
- Produces:
  - `Stage()` — composes wallpaper + `MenuBar` + `Notch` (+ `ActCard` when a session has `act`) + 1–2 `TerminalWindow`s. Wires: first interaction anywhere in the stage → `interject()`; a "▶ Resume demo" affordance (shown while `driving`) → `resume()`; row click → `jump(id)` → focus that terminal + show a toast; act resolution → `resolveAct`. Uses `useReducedMotion()` to gate animation/auto-play.
  - `Hero()` — kicker + serif `Claude`<em>Notch</em> H1 + subhead + CTA row (primary `Button` "Download for macOS" → `#download`, ghost "See it in action" → `#act`) + `<Stage/>`. Include the tap-to-interject hint copy.
  - `Button({ variant, href, children })` — primary (`bg-accent text-on-accent`) / ghost; renders `<a>` when `href` given else `<button>`.
- Toast: a small fixed element in `Stage` (`role="status"`) showing "→ focusing …" for ~1.6s.

- [ ] **Step 1: Build `Button`, `Stage`, `Hero`; clean up `page.tsx`** so it renders `<Hero/>` only (plus nothing temporary).

- [ ] **Step 2: Verify**

```bash
cd web && npx tsc --noEmit && npm run lint && npm run build
```
Expected: clean. `npm run dev` → hero shows the stage; on load it **auto-plays** (sessions progress, a permission card appears and auto-resolves on a loop). Click anywhere in the stage → auto-play pauses, "Resume demo" appears; click a row → matching terminal flashes + toast; trigger/act on a card → it resolves and the session continues; "Resume demo" → auto-play restarts. Switch theme → whole stage recolors. Reduced-motion → no animation, static representative composition, interactions still work.

- [ ] **Step 3: Commit**

```bash
cd /Users/navjotdhanawat/Workspace/claude-notch
git add web && git commit -m "$(printf 'feat: interactive stage + hero (auto-play, tap-to-interject, jump)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 7: ThemeSwitcher in the menu bar (product-authentic live switch)

**Files:**
- Create: `web/components/ThemeSwitcher.tsx`
- Modify: `web/components/stage/Stage.tsx` (pass `<ThemeSwitcher/>` into `MenuBar`'s `right` slot)

**Interfaces:**
- Consumes: `useTheme`, `THEME_ORDER`, `PALETTES`.
- Produces: `ThemeSwitcher()` — a menu-bar control: a small button showing the active theme; on click opens a dropdown of all 10 themes (each a swatch of surface/accent/done dots + name), `aria-pressed`/checkmark on the active one; selecting calls `setTheme`. Closes on outside click / Escape; keyboard navigable.

- [ ] **Step 1: Build `ThemeSwitcher`** and mount it in the menu bar's right slot (beside a mock clock).

- [ ] **Step 2: Verify**

```bash
cd web && npx tsc --noEmit && npm run lint && npm run build
```
Expected: clean. `npm run dev` → the menu-bar control opens a 10-theme dropdown; picking "Dune"/"Matrix" recolors the whole page + stage live and marks the active item; reload persists; Escape/outside-click closes; Tab reaches items.

- [ ] **Step 3: Commit**

```bash
cd /Users/navjotdhanawat/Workspace/claude-notch
git add web && git commit -m "$(printf 'feat: menu-bar theme switcher (live global recolor)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 8: Marketing sections I — How it works, Act in place, Capabilities

**Files:**
- Create: `web/components/ui/Section.tsx`, `web/components/sections/HowItWorks.tsx`, `ActInPlace.tsx`, `Capabilities.tsx`
- Modify: `web/app/page.tsx` (add the three sections after `<Hero/>`)

**Interfaces:**
- Produces: `Section({ id, num, title, note, children })` shared wrapper (numbered head + reveal-ready); the three sections. `ActInPlace` reuses `ActCard` (three static-but-clickable cards) — pass fixture prompts and a local resolve that shows a resolved state + a reset.

- [ ] **Step 1: `Section` wrapper** (kicker number in `text-accent`, serif title, optional note).

- [ ] **Step 2: `HowItWorks`** — 3-step strip: hooks → `notch-bridge` (localhost + `ITERM_SESSION_ID`) → notch/jump. Tagline "No yabai. No cloud. No telemetry."

- [ ] **Step 3: `ActInPlace`** (`id="act"`) — the trio using `ActCard` with fixtures; each resolves on click and offers a reset. Honesty note re: number chips = visual index.

- [ ] **Step 4: `Capabilities`** (`id="features"`) — responsive grid of the 12 capabilities (spec §7.1), each glyph + title + one-line desc, accurate to shipped reality (Gemini planned).

- [ ] **Step 5: Verify**

```bash
cd web && npx tsc --noEmit && npm run lint && npm run build
```
Expected: clean. `npm run dev` → the three sections render below the hero; act cards resolve+reset; capability grid reflows; all recolor with theme; nav-anchor ids present (`#act`, `#features`).

- [ ] **Step 6: Commit**

```bash
cd /Users/navjotdhanawat/Workspace/claude-notch
git add web && git commit -m "$(printf 'feat: sections - how-it-works, act-in-place, capabilities\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 9: Marketing sections II — Agents/Terminals, Themes gallery, Roadmap

**Files:**
- Create: `web/components/sections/AgentsTerminals.tsx`, `ThemesGallery.tsx`, `Roadmap.tsx`; `web/components/ui/Chip.tsx`
- Modify: `web/app/page.tsx`

**Interfaces:**
- Produces:
  - `Chip({ on })` — solid (shipping) / dashed (via seam) chip.
  - `AgentsTerminals()` (`id` optional) — example rows + two chip groups: Agents (Claude on, Codex on, Gemini soon); Terminals (iTerm2/WezTerm/Kitty on; Terminal.app/Ghostty/Warp/tmux/VS Code soon); badge-tint legend; note the `AgentProvider`/`TerminalJumper` seams.
  - `ThemesGallery()` (`id="themes"`) — 10 `themecard` buttons, each a mini-notch preview rendered in that theme's OWN palette (inline `style` from `PALETTES[id]`, NOT the global vars), name, active ring; clicking calls `setTheme`; stays in sync with the menu-bar switcher (both via `useTheme`).
  - `Roadmap()` (`id="roadmap"`) — SSH remote / mobile relay / cost & limits, tagged later/exploring.

- [ ] **Step 1–3: Build the three sections + `Chip`** per interfaces (adapt agents/roadmap visuals from mockup lines 490–545).

- [ ] **Step 4: Verify**

```bash
cd web && npx tsc --noEmit && npm run lint && npm run build
```
Expected: clean. `npm run dev` → gallery shows 10 cards each in its own palette; clicking one recolors the whole page AND syncs the menu-bar switcher's active state; agents/terminals chips accurate; roadmap tagged.

- [ ] **Step 5: Commit**

```bash
cd /Users/navjotdhanawat/Workspace/claude-notch
git add web && git commit -m "$(printf 'feat: sections - agents/terminals, themes gallery, roadmap\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 10: Nav, final CTA band, Footer, page composition

**Files:**
- Create: `web/components/sections/Nav.tsx`, `CTA.tsx`, `Footer.tsx`
- Modify: `web/app/page.tsx` (final order)

**Interfaces:**
- Produces:
  - `Nav()` — sticky top nav: wordmark · links (`#features #act #themes #roadmap`) · Download button (`#download`).
  - `CTA()` (`id="download"`) — band: headline, primary "Download for macOS" (placeholder `href="#"` with `data-download`), requirements line (Apple Silicon · macOS 14+ · iTerm2/WezTerm/Kitty · Claude Code), placeholder note.
  - `Footer()` — local-only/no cloud/no telemetry/no yabai, DynamicNotchKit credit, honesty note (Download placeholder).
- Final `page.tsx` order: `<Nav/>` then `<Hero/> <HowItWorks/> <ActInPlace/> <Capabilities/> <AgentsTerminals/> <ThemesGallery/> <Roadmap/> <CTA/> <Footer/>`.

- [ ] **Step 1: Build Nav, CTA, Footer; finalize `page.tsx`.**

- [ ] **Step 2: Verify**

```bash
cd web && npx tsc --noEmit && npm run lint && npm run build
```
Expected: clean. `npm run dev` → full page in order; sticky nav; anchor links jump to sections; CTA + footer render; Download is a placeholder; theme recolors everything.

- [ ] **Step 3: Commit**

```bash
cd /Users/navjotdhanawat/Workspace/claude-notch
git add web && git commit -m "$(printf 'feat: nav, final CTA band, footer, full page composition\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Task 11: Motion/a11y/responsive polish, metadata/OG, README, final verification

**Files:**
- Create: `web/README.md`
- Modify: `web/app/globals.css`, `web/app/layout.tsx` (OG/metadata), section wrappers (scroll reveal), responsive tweaks across components

**Interfaces:** consumes all prior work.

- [ ] **Step 1: Scroll reveal** — add a small `"use client"` reveal wrapper (or use `motion`'s `whileInView` with `viewport={{ once: true }}`) on each `Section`; gate with `useReducedMotion()` so content is immediately visible when reduced.

- [ ] **Step 2: A11y + responsive** — ensure `:focus-visible` styles (globals.css), `aria-pressed` on theme controls (verify), and responsive breakpoints: at ≤900px grids collapse to 1 col, the stage scales/reflows and stays legible/tappable, nav condenses. Confirm the reduced-motion block in globals.css covers Motion (Motion respects it via `useReducedMotion`, but also keep the CSS `@media` guard for CSS transitions).

- [ ] **Step 3: Metadata/OG** — in `layout.tsx` add `openGraph`/`twitter` metadata (title, description, type website). (No external image required; a text-based OG is fine.)

- [ ] **Step 4: `web/README.md`**

```markdown
# ClaudeNotch — Landing Page (Next.js)

Interactive marketing site for ClaudeNotch.

## Develop
    cd web && npm install && npm run dev   # http://localhost:3000

## Build
    npm run build && npm start

## Deploy
Deploy `web/` to Vercel (import the repo, root directory = `web/`). Standard Next.js build.

## Theming
The live theme switcher mirrors the app's 10 built-in themes; hex values in `lib/themes.ts`
are kept in sync with `Sources/ClaudeNotchApp/UI/Themes.swift` / `Palette.swift`.
```

- [ ] **Step 5: Final verification pass**

```bash
cd web && npx tsc --noEmit && npm run lint && npm run build
```
Expected: all clean, build succeeds. Then `npm run dev` and confirm end-to-end:
- All sections present, in order; nav anchors jump.
- Auto-play loops; tap-to-interject pauses + hands over; resume works; row click focuses terminal + toast; act cards resolve.
- Theme switch (menu-bar AND gallery) recolors the whole page + stage, stays in sync, persists on reload.
- OS "Reduce Motion" on → reload → no animation, content visible, interactions still work.
- Narrow to ~375px → grids collapse to one column; stage reflows; nothing overflows horizontally.
- DevTools console: zero errors/warnings.

- [ ] **Step 6: Commit**

```bash
cd /Users/navjotdhanawat/Workspace/claude-notch
git add web && git commit -m "$(printf 'feat: motion/a11y/responsive polish, OG metadata, README, final verification\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Self-Review

**Spec coverage** (spec §§ → tasks):
- §3 stack/layout → Task 1 (scaffold, fonts, globals) + structure across all tasks. ✓
- §4 visual language → Task 1 + stage components (Tasks 4–6) + sections. ✓
- §5 theming (palettes, resolver, provider, CSS vars, Tailwind mapping, two switchers, persistence) → Task 2 (engine) + Task 7 (menu-bar) + Task 9 (gallery). ✓
- §6 playground (auto-play, interject, actions, reduced-motion, engine) → Task 3 (engine) + Task 5 (act card) + Task 6 (stage/hero) + Task 7 (theme). ✓
- §7 page structure (nav/hero/how/act/features/agents/themes/roadmap/CTA/footer) → Tasks 6, 8, 9, 10. ✓
- §7.1 capability inventory → Task 8 (Capabilities). ✓
- §8 accuracy rules → enforced in copy (Tasks 3, 8, 9, 10) + Global Constraints. ✓
- §9 motion/a11y → Tasks 4–7 (per-component) + Task 11 (pass). ✓
- §10 responsive → Task 11 (+ components built fluid). ✓
- §11 deliverables (web app + README, remove site/) → Task 1 (remove site/) + all tasks + Task 11 (README). ✓
- §12 verification → per-task tsc/lint/build + browser checks + Task 11 full pass. ✓

**Placeholder scan:** No "TBD/handle edge cases". The Download `href="#"` is an intentional, disclosed product decision, not a gap. Debug/temporary renders in Tasks 2–5 are explicitly removed by Task 6.

**Type/name consistency:** `ThemeId`, `Palette`, `PALETTES`, `THEME_ORDER`, `paletteVars`, `useTheme`, `Session`, `SessionState`, `ActKind`, `ActPrompt`, `useSimulatedSessions` (`interject/resume/resolveAct/jump/spawn`), CSS vars (`--surface-top`…`--accent`) and Tailwind tokens (`bg-surface-top`, `text-accent`, `border-border-c`, `bg-st-working`, `text-ag-claude`) are used consistently across tasks. Menu-bar switcher (Task 7) and gallery (Task 9) both key off `useTheme` so they stay in sync.

**Note on TDD:** Per project standard (CLAUDE.md), no automated test suite is added unprompted; verification is `tsc`/`lint`/`build` + observable browser checks. Optional Vitest units for `lib/themes.ts` resolver + `useSimulatedSessions` reducer are available if the user asks.
