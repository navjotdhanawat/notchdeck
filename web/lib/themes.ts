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
