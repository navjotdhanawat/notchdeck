export type SessionState =
  | "working"
  | "needsPermission"
  | "needsInput"
  | "done"
  | "failed";

export type ActKind = "permission" | "ask" | "plan";
export type AgentId = "claude" | "codex" | "gemini";

export interface DiffLine {
  type: "context" | "add" | "del";
  lineNo: string;
  text: string;
}

export interface ActPrompt {
  kind: ActKind;
  question?: string;
  file?: string;
  added?: number;
  removed?: number;
  diff?: DiffLine[];
  steps?: string[];
  headline?: string;
}

export interface Session {
  id: string;
  title: string;
  agent: AgentId;
  terminal: string;
  state: SessionState;
  activity: string;
  elapsedMin: number;
  act?: ActPrompt;
  tokens?: number;
  cost?: number;
}

export interface Palette {
  name: string;
  surfaceTop: string;
  surfaceBottom: string;
  innerBox: string;
  border: string;
  textPrimary: string;
  textSecondary: string;
  onAccent: string;
  working: string;
  done: string;
  failed: string;
  needsPermission: string;
  plan: string;
  question: string;
  ended: string;
  needsInputDot: string;
  agentClaude: string;
  agentCodex: string;
  agentGemini: string;
  accent: string;
}

const rgba = (hex: string, a: number) => {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
};

export const GRAPHITE: Palette = {
  name: "Graphite",
  surfaceTop: "#131316",
  surfaceBottom: "#0C0C0E",
  innerBox: rgba("#000000", 0.28),
  border: rgba("#FFFFFF", 0.12),
  textPrimary: "#ECEAE4",
  textSecondary: "#8B8B93",
  onAccent: "#ffffff",
  working: "#0A84FF",
  done: "#30D158",
  failed: "#FF453A",
  needsPermission: "#FF9F0A",
  plan: "#A78BFA",
  question: "#5AC8FA",
  ended: rgba("#8B8B93", 0.75),
  needsInputDot: "#FFD60A",
  agentClaude: "#00D8F6",
  agentCodex: "#5FD0B0",
  agentGemini: "#8FB0F9",
  accent: "#00D8F6",
};
