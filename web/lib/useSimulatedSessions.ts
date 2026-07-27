"use client";
// Simulated-session engine: a self-contained reducer + timer that AUTO-PLAYS a
// deterministic, looping demo of Claude/Codex/Gemini sessions, and lets a
// visitor TAP IN (interject) to drive it. Presentation-agnostic — the Stage
// (Tasks 4–6) renders this data and decides whether to animate.

import { useCallback, useEffect, useReducer, useRef } from "react";
import {
  ACT_FIXTURES,
  SEED_SESSIONS,
  type AgentId,
  type Session,
} from "@/lib/types";

/** Auto-play cadence. ~2.2s per beat. */
const TICK_MS = 2200;

// --- pure helpers -----------------------------------------------------------

const setS = (arr: Session[], id: string, patch: Partial<Session>): Session[] =>
  arr.map((s) => (s.id === id ? { ...s, ...patch } : s));

const upsert = (arr: Session[], session: Session): Session[] =>
  arr.some((s) => s.id === session.id)
    ? setS(arr, session.id, session)
    : [...arr, session];

const remove = (arr: Session[], id: string): Session[] =>
  arr.filter((s) => s.id !== id);

/**
 * The scripted timeline. A rotating array of pure beats applied one-per-tick
 * (`BEATS[step % BEATS.length]`). Each beat force-sets the fields it touches so
 * the loop is self-healing and can NEVER stall — no randomness drives progress.
 * One full cycle (~9 beats × 2.2s ≈ 20s) tells the whole story, then repeats.
 */
const BEATS: Array<(s: Session[]) => Session[]> = [
  // 0 — Claude blocks on a permission (Edit src/auth/middleware.ts).
  (s) =>
    setS(s, "s1", {
      state: "needsPermission",
      activity: "Needs permission · Edit middleware.ts",
      act: ACT_FIXTURES.permission,
    }),
  // 1 — life goes on: Codex keeps churning next to the blocked one.
  (s) => setS(s, "s2", { state: "working", activity: "Compiling routes…", act: undefined }),
  // 2 — permission granted → Claude applies the edit.
  (s) =>
    setS(s, "s1", {
      state: "working",
      activity: "Applying edit to middleware.ts…",
      act: undefined,
    }),
  // 3 — a deploy session spawns with a plan awaiting sign-off.
  (s) =>
    upsert(s, {
      id: "auto-4",
      title: "deploy api",
      agent: "claude",
      terminal: "WezTerm",
      state: "needsInput",
      activity: "Plan ready · review",
      elapsedMin: 2,
      act: ACT_FIXTURES.plan,
      usage: {
        tokens: { input: 8200, output: 2100, cacheCreation: 1000, cacheRead: 4000, total: 15300 }
      }
    }),
  // 4 — Claude asks a follow-up (deployment target).
  (s) =>
    setS(s, "s1", {
      state: "needsInput",
      activity: "Waiting on your answer",
      act: ACT_FIXTURES.ask,
    }),
  // 5 — answered → deploying; plan approved on the deploy session.
  (s) =>
    setS(
      setS(s, "s1", { state: "working", activity: "Deploying to Staging…", act: undefined }),
      "auto-4",
      { state: "working", activity: "Executing plan · step 1/6", act: undefined },
    ),
  // 6 — Codex finishes.
  (s) => setS(s, "s2", { state: "done", activity: "Done · server ready", act: undefined }),
  // 7 — Claude finishes; revive the idle query job so the list stays alive.
  (s) =>
    setS(
      setS(s, "s1", { state: "done", activity: "Done · auth bug fixed", act: undefined }),
      "s3",
      { state: "working", activity: "Re-running query benchmarks…" },
    ),
  // 8 — retire the deploy session; reset the trio for the next loop.
  (s) =>
    setS(
      setS(remove(s, "auto-4"), "s1", {
        state: "working",
        activity: "Writing middleware.ts…",
        act: undefined,
      }),
      "s2",
      { state: "working", activity: "Running dev server…", act: undefined },
    ),
];

// --- spawn() rotation pools -------------------------------------------------

const SPAWN_TITLES = [
  "refactor api",
  "write tests",
  "update deps",
  "fix flaky test",
  "add caching",
  "migrate db",
];
const SPAWN_AGENTS: AgentId[] = ["claude", "codex", "gemini"];
const SPAWN_TERMINALS = ["iTerm2", "WezTerm", "Kitty", "Terminal", "Ghostty"];

// --- reducer ----------------------------------------------------------------

interface EngineState {
  sessions: Session[];
  /** A visitor has taken over (auto-play paused). */
  driving: boolean;
  /** The scripted timeline is running. */
  autoplay: boolean;
  /** Timeline cursor. */
  step: number;
  /** Monotonic counter for spawn() ids/rotation. */
  spawnCount: number;
}

type Action =
  | { type: "TICK" }
  | { type: "INTERJECT" }
  | { type: "RESUME" }
  | { type: "RESOLVE_ACT"; id: string; choice: string }
  | { type: "SPAWN" };

/** Fresh deterministic state — identical on server and first client render. */
function makeInitial(): EngineState {
  return {
    sessions: SEED_SESSIONS.map((s) => ({ ...s })),
    driving: false,
    autoplay: true,
    step: 0,
    spawnCount: 0,
  };
}

function reducer(state: EngineState, action: Action): EngineState {
  switch (action.type) {
    case "TICK": {
      // Age active sessions so elapsed climbs; done/failed freeze.
      const aged = state.sessions.map((s) =>
        s.state === "done" || s.state === "failed"
          ? s
          : { ...s, elapsedMin: Math.min(s.elapsedMin + 1, 599) },
      );
      const beat = BEATS[state.step % BEATS.length];
      return { ...state, sessions: beat(aged), step: state.step + 1 };
    }

    case "INTERJECT":
      // First visitor interaction: take over, pause the timeline.
      return { ...state, driving: true, autoplay: false };

    case "RESUME":
      // Hand back to auto-play: restart the timeline from a clean seed.
      return { ...makeInitial(), driving: false, autoplay: true };

    case "SPAWN": {
      const i = state.spawnCount;
      const spawned: Session = {
        id: `spawn-${i}`,
        title: SPAWN_TITLES[i % SPAWN_TITLES.length],
        agent: SPAWN_AGENTS[i % SPAWN_AGENTS.length],
        terminal: SPAWN_TERMINALS[i % SPAWN_TERMINALS.length],
        state: "working",
        activity: "Starting up…",
        elapsedMin: 0,
      };
      return {
        ...state,
        sessions: [...state.sessions, spawned],
        spawnCount: i + 1,
      };
    }

    case "RESOLVE_ACT": {
      const { id } = action;
      const choice = action.choice;
      const c = choice.toLowerCase();
      const sessions = state.sessions.map((s) => {
        if (s.id !== id || !s.act) return s;
        switch (s.act.kind) {
          case "permission": {
            const denied = c.includes("deny");
            return {
              ...s,
              act: undefined,
              state: denied ? ("failed" as const) : ("working" as const),
              activity: denied ? "Denied · change reverted" : "Allowed · applying edit…",
            };
          }
          case "ask":
            return {
              ...s,
              act: undefined,
              state: "working" as const,
              activity: `Chose ${choice}`,
            };
          case "plan": {
            const changes = c.includes("request") || c.includes("change");
            return {
              ...s,
              act: undefined,
              state: changes ? ("needsInput" as const) : ("working" as const),
              activity: changes ? "Requested changes · revising plan" : "Plan approved · executing",
            };
          }
        }
      });
      return { ...state, sessions };
    }

    default:
      return state;
  }
}

// --- hook -------------------------------------------------------------------

export interface UseSimulatedSessions {
  sessions: Session[];
  driving: boolean;
  autoplay: boolean;
  interject(): void;
  resume(): void;
  resolveAct(id: string, choice: string): void;
  jump(id: string): string;
  spawn(): void;
}

export function useSimulatedSessions(): UseSimulatedSessions {
  const [state, dispatch] = useReducer(reducer, undefined, makeInitial);

  // Stored interval id (cleared on unmount + on interject via the effect's
  // dependency on `autoplay`).
  const intervalRef = useRef<number | null>(null);

  // Timer setup is client-only: effects never run during SSR, and we still
  // guard `window` for defensiveness. Re-runs whenever autoplay flips, so
  // interject() (autoplay=false) clears the interval and resume() restarts it.
  useEffect(() => {
    if (!state.autoplay || typeof window === "undefined") return;
    intervalRef.current = window.setInterval(() => dispatch({ type: "TICK" }), TICK_MS);
    return () => {
      if (intervalRef.current !== null) {
        window.clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
    };
  }, [state.autoplay]);

  const interject = useCallback(() => dispatch({ type: "INTERJECT" }), []);
  const resume = useCallback(() => dispatch({ type: "RESUME" }), []);
  const spawn = useCallback(() => dispatch({ type: "SPAWN" }), []);
  const resolveAct = useCallback(
    (id: string, choice: string) => dispatch({ type: "RESOLVE_ACT", id, choice }),
    [],
  );
  // Side-effect-free label read; recreated when sessions change so it always
  // reflects the latest list (no ref access during render).
  const jump = useCallback(
    (id: string): string => {
      const s = state.sessions.find((x) => x.id === id);
      return s ? `${s.terminal} · ${s.title}` : "";
    },
    [state.sessions],
  );

  return {
    sessions: state.sessions,
    driving: state.driving,
    autoplay: state.autoplay,
    interject,
    resume,
    resolveAct,
    jump,
    spawn,
  };
}
