"use client";
// The playground centerpiece: a framed, contained macOS "stage" (wallpaper +
// menubar + notch panel + terminal peek) that AUTO-PLAYS a looping demo of the
// simulated sessions and lets a visitor TAP IN to drive it. Everything reads off
// theme tokens (the wallpaper is mixed from the palette), so switching themes
// recolors the whole scene. All animation + the auto-play timeline are gated by
// prefers-reduced-motion: reduced ⇒ a static, representative composition whose
// controls (jump, resolve) still work.

import { useCallback, useEffect, useRef, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useSimulatedSessions } from "@/lib/useSimulatedSessions";
import type { Session } from "@/lib/types";
import { ActCard } from "@/components/stage/ActCard";
import { MenuBar } from "@/components/stage/MenuBar";
import { Notch } from "@/components/stage/Notch";
import { TerminalWindow } from "@/components/stage/TerminalWindow";
import { ThemeSwitcher } from "@/components/ThemeSwitcher";

/** macOS system stack for the menubar/overlay chrome (not the page serif). */
const SYS =
  "-apple-system,BlinkMacSystemFont,'SF Pro Text','Helvetica Neue',Arial,sans-serif";

/** Aggregate usage shown in the notch header — tokens + cost only (spec §8). */
const USAGE = { tokens: "1.2M", cost: "$2.14" } as const;

/** "fix auth bug" → "fix-auth-bug" (branch/project style, matches the mockup). */
const projectLabel = (title: string) =>
  title.trim().toLowerCase().replace(/\s+/g, "-");

/**
 * A themed Monterey-ish wallpaper mixed from palette tokens so it recolors with
 * the theme (accent + the perm/plan/ask state hues over the surface gradient).
 */
const WALLPAPER: React.CSSProperties = {
  backgroundColor: "var(--surface-bottom)",
  backgroundImage: [
    "radial-gradient(120% 90% at 78% 12%, color-mix(in srgb, var(--accent) 62%, transparent) 0%, transparent 44%)",
    "radial-gradient(90% 85% at 60% 40%, color-mix(in srgb, var(--st-perm) 42%, transparent) 0%, transparent 55%)",
    "radial-gradient(85% 78% at 16% 84%, color-mix(in srgb, var(--st-plan) 48%, transparent) 0%, transparent 58%)",
    "radial-gradient(80% 70% at 94% 90%, color-mix(in srgb, var(--st-ask) 32%, transparent) 0%, transparent 55%)",
    "linear-gradient(158deg, var(--surface-top) 0%, color-mix(in srgb, var(--st-plan) 28%, var(--surface-bottom)) 44%, color-mix(in srgb, var(--accent) 34%, var(--surface-bottom)) 100%)",
  ].join(", "),
};

/** Build a terminal peek that reflects a live session (title + activity). */
function terminalFor(session: Session | undefined, tail: string) {
  if (!session) return { title: "—", lines: ["● idle"] };
  return {
    title: `${session.agent} — ${projectLabel(session.title)}`,
    lines: [`● ${session.activity}`, `  ${tail}`],
  };
}

export function Stage() {
  const { sessions, driving, autoplay, interject, resume, resolveAct, jump } =
    useSimulatedSessions();
  const reduce = useReducedMotion();

  const [focusedId, setFocusedId] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [clock, setClock] = useState("");
  const flashTimer = useRef<number | null>(null);

  // Client-only clock — empty on SSR so first client render matches (no
  // hydration mismatch), then set/ticked after mount.
  useEffect(() => {
    const tick = () =>
      setClock(
        new Date().toLocaleTimeString([], { hour: "numeric", minute: "2-digit" }),
      );
    tick();
    const id = window.setInterval(tick, 30_000);
    return () => window.clearInterval(id);
  }, []);

  // Reduced motion ⇒ freeze the auto-play timeline into a static, representative
  // composition (the seed already has a pending permission). interject() stops
  // the engine's interval; the Resume affordance is hidden under reduce, so the
  // scene stays still while jump/resolve remain fully interactive.
  useEffect(() => {
    if (reduce) interject();
  }, [reduce, interject]);

  useEffect(
    () => () => {
      if (flashTimer.current !== null) window.clearTimeout(flashTimer.current);
    },
    [],
  );

  // First interaction anywhere in the stage takes over (pauses auto-play).
  // Capture phase runs before row/card handlers, so a single click both
  // interjects AND performs its action (jump / resolve).
  const takeOver = useCallback(() => {
    if (!driving) interject();
  }, [driving, interject]);

  // Row click → focus the matching terminal peek + announce a toast (~1.6s).
  const onJump = useCallback(
    (id: string) => {
      const label = jump(id);
      setFocusedId(id);
      setToast(label ? `→ focusing ${label}` : "→ focusing session");
      if (flashTimer.current !== null) window.clearTimeout(flashTimer.current);
      flashTimer.current = window.setTimeout(() => {
        setFocusedId(null);
        setToast(null);
      }, 1600);
    },
    [jump],
  );

  const activeSession = sessions.find((s) => s.act);
  const cardSession = activeSession ?? sessions[0];

  // Two stable terminal peeks bound to the seed sessions the timeline keeps
  // alive (s1 Claude, s2 Codex); clicking either row flashes its window.
  const s1 = sessions.find((s) => s.id === "s1");
  const s2 = sessions.find((s) => s.id === "s2");
  const termA = terminalFor(s1, "Searching for 6 patterns… (ctrl+o to expand)");
  const termB = terminalFor(s2, "watching for changes · esc to interrupt");

  return (
    <div
      onPointerDownCapture={takeOver}
      onKeyDownCapture={takeOver}
      style={WALLPAPER}
      className="relative isolate overflow-hidden rounded-[22px] border border-white/12 shadow-[0_40px_90px_-38px_rgba(0,0,0,0.9),inset_0_1px_0_rgba(255,255,255,0.06)]"
    >
      {/* soft top vignette for depth over the wallpaper */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 z-0"
        style={{
          background:
            "radial-gradient(130% 80% at 50% 0%, transparent 58%, rgba(0,0,0,0.45) 100%)",
        }}
      />

      <MenuBar
        right={
          <>
            <ThemeSwitcher />
            <span className="font-mono text-[11.5px] tabular-nums text-text-primary">
              {clock}
            </span>
          </>
        }
      />

      {/* auto-play / resume affordance (top-right of the desktop) */}
      {!reduce && (
        <div className="absolute right-3 top-11 z-30" style={{ fontFamily: SYS }}>
          {driving ? (
            <button
              type="button"
              onClick={resume}
              aria-label="Resume the auto-playing demo"
              className="inline-flex items-center gap-2 rounded-full border border-white/20 bg-black/45 px-3 py-1.5 text-[12px] font-medium text-text-primary backdrop-blur-md transition hover:-translate-y-px hover:bg-black/60 focus:outline-none focus-visible:ring-2 focus-visible:ring-accent/70"
            >
              <span aria-hidden className="text-accent">
                ▶
              </span>
              Resume demo
            </button>
          ) : (
            autoplay && (
              <span className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-black/40 px-3 py-1.5 text-[11px] font-medium text-text-secondary backdrop-blur-md">
                <motion.span
                  aria-hidden
                  className="h-[7px] w-[7px] flex-none rounded-full bg-st-done"
                  style={{ boxShadow: "0 0 8px currentColor" }}
                  animate={{ opacity: [1, 0.35, 1] }}
                  transition={{ duration: 1.6, repeat: Infinity, ease: "easeInOut" }}
                />
                Live demo · playing
              </span>
            )
          )}
        </div>
      )}

      {/* desktop */}
      <div className="relative z-10 px-4 pb-9 pt-0 sm:px-6">
        {/* notch panel (with the act-card overlay slot) */}
        <div className="relative z-20 overflow-visible">
          <Notch sessions={sessions} usage={USAGE} onJump={onJump}>
            <ActCard
              prompt={activeSession?.act ?? null}
              session={cardSession}
              onResolve={(choice) => resolveAct(cardSession.id, choice)}
            />
          </Notch>
        </div>

        {/* terminal peeks tucked cleanly below the panel */}
        <div className="relative z-0 mx-auto mt-4 grid max-w-[760px] gap-3 sm:grid-cols-2">
          <TerminalWindow
            title={termA.title}
            lines={termA.lines}
            focused={focusedId === "s1"}
          />
          <TerminalWindow
            title={termB.title}
            lines={termB.lines}
            focused={focusedId === "s2"}
          />
        </div>
      </div>

      {/* toast — a fixed, contained live region announcing the jump target */}
      <div
        role="status"
        aria-live="polite"
        className="pointer-events-none absolute inset-x-0 bottom-4 z-40 flex justify-center"
        style={{ fontFamily: SYS }}
      >
        <AnimatePresence>
          {toast && (
            <motion.div
              key={toast}
              initial={reduce ? false : { opacity: 0, y: 10, scale: 0.96 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={reduce ? { opacity: 0 } : { opacity: 0, y: 10, scale: 0.96 }}
              transition={{ duration: reduce ? 0 : 0.2, ease: "easeOut" }}
              className="rounded-full border border-white/15 bg-black/70 px-4 py-2 text-[12.5px] font-medium text-text-primary shadow-[0_10px_30px_-10px_rgba(0,0,0,0.8)] backdrop-blur-md"
            >
              {toast}
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
