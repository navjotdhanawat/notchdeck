import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { GRAPHITE } from "../types";
import type { Session } from "../types";
import { MenuBar } from "../components/MenuBar";
import { NotchPanel } from "../components/NotchPanel";
import { TerminalWindow } from "../components/TerminalWindow";
import { PermissionCard } from "../components/PermissionCard";

// ─── Storyboard (30fps) ────────────────────────────────────────────────────
// 0–90    (0–3s)   — desktop, empty notch hint
// 90–180  (3–6s)   — session 1 spawns: Claude "fix auth bug" working
// 180–300 (6–10s)  — session 2 spawns: Codex "backend server"
// 300–420 (10–14s) — session 3 spawns: Claude "optimize queries"
// 420–540 (14–18s) — session 2 hits needsPermission, PermissionCard slides in
// 540–630 (18–21s) — permission approved → session 2 done ✓
// 630–750 (21–25s) — terminal window jumps (accent ring flash) on session 1
// 750–870 (25–29s) — sessions 1 & 3 done, cost summary shown
// 870–900 (29–30s) — fade out, logo card

const FPS = 30;
const p = GRAPHITE;

// Ease a spring entrance: returns 0→1 progress from a given start frame
function entrance(frame: number, startFrame: number, fps: number): number {
  return spring({
    frame: frame - startFrame,
    fps,
    config: { damping: 14, stiffness: 120, mass: 0.6 },
    durationInFrames: 40,
  });
}

const SESSION_1: Session = {
  id: "s1",
  title: "fix auth bug",
  agent: "claude",
  terminal: "iTerm2",
  state: "working",
  activity: "Writing middleware.ts…",
  elapsedMin: 3,
};

const SESSION_2_WORKING: Session = {
  id: "s2",
  title: "backend server",
  agent: "codex",
  terminal: "WezTerm",
  state: "working",
  activity: "Refactoring routes…",
  elapsedMin: 1,
};

const SESSION_2_PERM: Session = {
  id: "s2",
  title: "backend server",
  agent: "codex",
  terminal: "WezTerm",
  state: "needsPermission",
  activity: "Needs permission · Edit middleware.ts",
  elapsedMin: 5,
  act: {
    kind: "permission",
    file: "middleware.ts",
    added: 4,
    removed: 1,
    diff: [
      { type: "context", lineNo: "12", text: "export async function auth(req) {" },
      { type: "del",     lineNo: "13", text: "  if (!req.token) return null;" },
      { type: "add",     lineNo: "",   text: "  if (!req.token) throw new" },
      { type: "add",     lineNo: "",   text: "    AuthError('missing');" },
    ],
  },
};

const SESSION_2_DONE: Session = {
  id: "s2",
  title: "backend server",
  agent: "codex",
  terminal: "WezTerm",
  state: "done",
  activity: "Done · 2 files changed",
  elapsedMin: 7,
};

const SESSION_3: Session = {
  id: "s3",
  title: "optimize queries",
  agent: "claude",
  terminal: "Kitty",
  state: "working",
  activity: "Analyzing slow queries…",
  elapsedMin: 2,
};

const SESSION_1_DONE: Session = {
  id: "s1",
  title: "fix auth bug",
  agent: "claude",
  terminal: "iTerm2",
  state: "done",
  activity: "Done · 5 files changed",
  elapsedMin: 28,
};

const SESSION_3_DONE: Session = {
  id: "s3",
  title: "optimize queries",
  agent: "claude",
  terminal: "Kitty",
  state: "done",
  activity: "Done · indexes added",
  elapsedMin: 22,
};

const TERM_LINES_WORKING = [
  "$ claude --resume fix-auth-bug",
  "> Reading auth/middleware.ts…",
  "> Identified 3 issues in token validation",
  "> Writing fix…",
  "▋",
];

const TERM_LINES_DONE = [
  "$ claude --resume fix-auth-bug",
  "> ✓ auth/middleware.ts updated",
  "> ✓ auth/validate.ts updated",
  "> ✓ tests/auth.spec.ts updated",
  "> Session complete. Cost: $0.04",
];

export function NotchDeckDemo() {
  const frame = useCurrentFrame();
  const { fps, width, height } = useVideoConfig();

  // ── derived per-frame state ───────────────────────────────────────────────
  const showS1 = frame >= 90;
  const showS2 = frame >= 180;
  const showS3 = frame >= 300;
  const showPerm = frame >= 420 && frame < 630;
  const s2Done = frame >= 540;
  const termFocused = frame >= 630 && frame < 750;
  const allDone = frame >= 750;
  const fadeOut = frame >= 870;

  const s1 = allDone ? SESSION_1_DONE : SESSION_1;
  const s2 = s2Done ? SESSION_2_DONE : showPerm ? SESSION_2_PERM : SESSION_2_WORKING;
  const s3 = allDone ? SESSION_3_DONE : SESSION_3;

  const sessions: Session[] = [
    ...(showS1 ? [s1] : []),
    ...(showS2 ? [s2] : []),
    ...(showS3 ? [s3] : []),
  ];

  // ── spring-driven y offsets for session entrance ──────────────────────────
  const s1Progress = showS1 ? entrance(frame, 90, fps) : 0;
  const s2Progress = showS2 ? entrance(frame, 180, fps) : 0;
  const s3Progress = showS3 ? entrance(frame, 300, fps) : 0;

  // Permission card slide-in
  const permProgress = showPerm ? entrance(frame, 420, fps) : 0;

  // Global fade out
  const globalOpacity = fadeOut
    ? interpolate(frame, [870, 900], [1, 0], { extrapolateRight: "clamp" })
    : 1;

  // Token/cost shown after all done
  const tokens = allDone ? "142.3k" : undefined;
  const cost = allDone ? "$0.18" : undefined;

  // ── layout ────────────────────────────────────────────────────────────────
  // Canvas is 1080×1080 (square). We scale the "desktop" to fit centrally.
  const SCALE = width / 1080;

  // Wallpaper gradient
  const wallpaper = `radial-gradient(ellipse at 30% 40%, #1a1f35 0%, ${p.surfaceTop} 60%, #0a0a0c 100%)`;

  return (
    <AbsoluteFill style={{ background: p.surfaceTop, opacity: globalOpacity }}>
      {/* Wallpaper */}
      <AbsoluteFill style={{ background: wallpaper }} />

      {/* Subtle grid overlay */}
      <AbsoluteFill
        style={{
          backgroundImage: `linear-gradient(${p.border} 1px, transparent 1px), linear-gradient(90deg, ${p.border} 1px, transparent 1px)`,
          backgroundSize: "60px 60px",
          opacity: 0.3,
        }}
      />

      {/* Full-width MenuBar — sits at the very top edge of the canvas */}
      <div
        style={{
          position: "absolute",
          top: 0,
          left: 0,
          right: 0,
          borderBottom: `1px solid ${p.border}`,
        }}
      >
        <MenuBar p={p} />
      </div>

      {/* Notch + terminal — centered column, below the menubar */}
      <AbsoluteFill
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "flex-start",
          paddingTop: 32, // height of MenuBar
        }}
      >
        <div
          style={{
            width: 860,
            transform: `scale(${SCALE})`,
            transformOrigin: "top center",
          }}
        >
          {/* Notch drops from the menubar */}
          <div style={{ position: "relative" }}>
            <NotchPanel
              sessions={sessions}
              p={p}
              tokens={tokens}
              cost={cost}
            >
              {/* PermissionCard layered inside notch */}
              {showPerm && (
                <div
                  style={{
                    transform: `translateY(${interpolate(permProgress, [0, 1], [20, 0])}px)`,
                    opacity: permProgress,
                  }}
                >
                  <PermissionCard session={SESSION_2_PERM} p={p} />
                </div>
              )}
            </NotchPanel>
          </div>

          {/* Terminal window peek below notch */}
          <div
            style={{
              marginTop: 48,
              padding: "0 40px",
              opacity: showS1 ? interpolate(s1Progress, [0, 1], [0, 0.9]) : 0,
            }}
          >
            <TerminalWindow
              title="iTerm2 — fix-auth-bug — claude"
              lines={allDone ? TERM_LINES_DONE : TERM_LINES_WORKING}
              p={p}
              focused={termFocused}
            />
          </div>
        </div>
      </AbsoluteFill>

      {/* Intro title card — shown 0–75 frames */}
      {frame < 75 && (
        <AbsoluteFill
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            opacity: interpolate(frame, [0, 20, 60, 75], [0, 1, 1, 0], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        >
          <div
            style={{
              fontFamily:
                "-apple-system,BlinkMacSystemFont,'SF Pro Display',Arial,sans-serif",
              fontSize: 56,
              fontWeight: 700,
              color: p.textPrimary,
              letterSpacing: -1.5,
              textAlign: "center",
            }}
          >
            NotchDeck
          </div>
          <div
            style={{
              fontFamily:
                "-apple-system,BlinkMacSystemFont,'SF Pro Text',Arial,sans-serif",
              fontSize: 22,
              color: p.textSecondary,
              marginTop: 12,
              textAlign: "center",
            }}
          >
            Your MacBook notch, reimagined as an AI agent command deck.
          </div>
          <div
            style={{
              marginTop: 24,
              fontSize: 14,
              color: p.accent,
              fontFamily: "monospace",
              opacity: 0.8,
            }}
          >
            notchdeck.app
          </div>
        </AbsoluteFill>
      )}

      {/* Outro logo card — shown 860–900 */}
      {frame >= 860 && (
        <AbsoluteFill
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            opacity: interpolate(frame, [860, 880], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        >
          <div
            style={{
              fontFamily:
                "-apple-system,BlinkMacSystemFont,'SF Pro Display',Arial,sans-serif",
              fontSize: 64,
              fontWeight: 700,
              color: p.textPrimary,
              letterSpacing: -2,
            }}
          >
            NotchDeck
          </div>
          <div
            style={{
              marginTop: 16,
              fontSize: 18,
              color: p.textSecondary,
              fontFamily:
                "-apple-system,BlinkMacSystemFont,'SF Pro Text',Arial,sans-serif",
            }}
          >
            Free & open source · notchdeck.app
          </div>
          <div
            style={{
              marginTop: 8,
              fontSize: 13,
              color: p.accent,
              fontFamily: "monospace",
            }}
          >
            github.com/navjotdhanawat/notchdeck
          </div>
        </AbsoluteFill>
      )}
    </AbsoluteFill>
  );
}
