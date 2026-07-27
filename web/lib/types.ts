// Domain types + fixtures for the simulated-session playground.
// Plain TS (no "use client") — safe to import from server or client.
// Mirrors the real ClaudeNotch app: states, agents, and act-in-place kinds.

/** Live state of a monitored session (mirrors the notch's 5 states). */
export type SessionState =
  | "working"
  | "needsPermission"
  | "needsInput"
  | "done"
  | "failed";

/** The five animation themes. */
export type AnimationThemeId = "lego" | "pacman" | "pokemon" | "mario" | "space";

/** Custom token usage stats. */
export interface TokenUsage {
  input: number;
  output: number;
  cacheCreation: number;
  cacheRead: number;
  total: number;
}

export interface SessionUsage {
  model?: string;
  tokens: TokenUsage;
  costUSD?: number;
}

/** The three act-in-place decision surfaces the notch can present. */
export type ActKind = "permission" | "ask" | "plan";

/** Coding agents. `gemini` is a valid tint but is *planned* (see spec §8). */
export type AgentId = "claude" | "codex" | "gemini";

/** One line of a permission diff preview. */
export interface DiffLine {
  /** `context` = unchanged, `add` = inserted (+), `del` = removed (−). */
  type: "context" | "add" | "del";
  /** Gutter line number; empty string for a wrapped continuation line. */
  lineNo: string;
  /** Code text, WITHOUT the leading +/− marker (the card renders that). */
  text: string;
}

/**
 * A blocking decision the session is waiting on. One shape covers all three
 * kinds; only the fields relevant to `kind` are populated. (Chosen over a
 * discriminated union so consumers — ActCard in Task 5 — can read fields off a
 * single stable type, matching the interface contract in the plan.)
 */
export interface ActPrompt {
  kind: ActKind;

  // permission ---------------------------------------------------------------
  /** Tool being requested, e.g. "Edit". */
  tool?: string;
  /** File the tool wants to touch, e.g. "src/auth/middleware.ts". */
  file?: string;
  /** Diff preview lines. */
  diff?: DiffLine[];
  /** Count of added (+) lines for the diffstat. */
  added?: number;
  /** Count of removed (−) lines for the diffstat. */
  removed?: number;

  // ask (AskUserQuestion) ----------------------------------------------------
  /** The question posed to the visitor. */
  question?: string;
  /** Selectable options (numbering is a visual index, not a shortcut — §8). */
  options?: string[];

  // plan ---------------------------------------------------------------------
  /** Visible plan steps (the card shows these). */
  steps?: string[];
  /** How many further steps are collapsed behind "+N more". */
  moreCount?: number;
}

/** A single monitored coding session. */
export interface Session {
  id: string;
  /** Task name or branch, e.g. "fix auth bug". */
  title: string;
  agent: AgentId;
  /** Terminal app label, e.g. "iTerm2" / "Terminal" / "Ghostty". */
  terminal: string;
  state: SessionState;
  /** What it's doing right now (the activity line). */
  activity: string;
  /** Elapsed time in minutes (rendered as 27m / 1h / 5h by the row). */
  elapsedMin: number;
  /** Present only while the session is blocked on a decision. */
  act?: ActPrompt;
  usage?: SessionUsage;
}

/**
 * Reusable act-in-place prompts. The autoplay timeline and the interactive
 * marketing sections attach these to sessions; the session supplies the
 * context (project · agent · terminal), the fixture supplies the copy.
 * Copy is intentionally accurate to spec §8 and the v2 mockup.
 */
export const ACT_FIXTURES: Record<ActKind, ActPrompt> = {
  // Permission: an Edit on src/auth/middleware.ts, +3 / −1.
  permission: {
    kind: "permission",
    tool: "Edit",
    file: "src/auth/middleware.ts",
    added: 3,
    removed: 1,
    diff: [
      { type: "context", lineNo: "12", text: "const verify = (token) =>" },
      { type: "del", lineNo: "13", text: "jwt.verify(token);" },
      { type: "add", lineNo: "13", text: "if (!token) throw new" },
      { type: "add", lineNo: "", text: "  AuthError('missing');" },
      { type: "add", lineNo: "14", text: "return jwt.verify(token);" },
    ],
  },
  // Ask: exactly Production / Staging / Local only (§8 — no other options).
  ask: {
    kind: "ask",
    question: "Which deployment target?",
    options: ["Production", "Staging", "Local only"],
  },
  // Plan: 4 visible steps + "+2 more".
  plan: {
    kind: "plan",
    steps: [
      "Add TokenService with refresh rotation",
      "Move JWT secret into Keychain",
      "Verify + refresh in middleware",
      "Add /auth/refresh route + tests",
    ],
    moreCount: 2,
  },
};

/**
 * Initial session set. Covers Claude/Codex/Gemini across iTerm2/Terminal/
 * Ghostty and spans working / needsPermission / done. Deep-cloned by the hook
 * on seed so this constant is never mutated.
 */
export const SEED_SESSIONS: Session[] = [
  {
    id: "s1",
    title: "fix auth bug",
    agent: "claude",
    terminal: "iTerm2",
    state: "working",
    activity: "Writing middleware.ts…",
    elapsedMin: 27,
    usage: {
      tokens: { input: 22100, output: 8400, cacheCreation: 5000, cacheRead: 15000, total: 50500 }
    }
  },
  {
    id: "s2",
    title: "backend server",
    agent: "codex",
    terminal: "Terminal",
    state: "needsPermission",
    activity: "Needs permission · Edit middleware.ts",
    elapsedMin: 60,
    act: ACT_FIXTURES.permission,
    usage: {
      tokens: { input: 12000, output: 4200, cacheCreation: 2000, cacheRead: 8000, total: 26200 }
    }
  },
  {
    id: "s3",
    title: "optimize queries",
    agent: "gemini",
    terminal: "Ghostty",
    state: "done",
    activity: "Done · 3 files changed",
    elapsedMin: 300,
    usage: {
      tokens: { input: 32000, output: 14200, cacheCreation: 10000, cacheRead: 70000, total: 126200 }
    }
  },
];
