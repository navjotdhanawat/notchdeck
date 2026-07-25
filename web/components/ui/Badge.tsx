import type { AgentId } from "@/lib/types";

/** Agent tint or a neutral chip (e.g. the terminal label). */
export type BadgeKind = AgentId | "neutral";

/** Agent → text-token; the fill/border are derived from it via `currentColor`. */
const AGENT_TINT: Record<AgentId, string> = {
  claude: "text-ag-claude",
  codex: "text-ag-codex",
  gemini: "text-ag-gemini",
};

/**
 * Small monospace chip. `kind="claude|codex|gemini"` tints text + a 10% fill +
 * 25% border off the agent color; `"neutral"` uses the surface tokens. All
 * colors come from the theme palette, so switching themes recolors the chip.
 */
export function Badge({
  kind = "neutral",
  children,
}: {
  kind?: BadgeKind;
  children: React.ReactNode;
}) {
  const isAgent = kind !== "neutral";
  return (
    <span
      className={[
        "inline-flex items-center whitespace-nowrap rounded-md border px-[7px] py-[2px] font-mono text-[10px] leading-none",
        isAgent
          ? `${AGENT_TINT[kind]} border-current/25 bg-current/10`
          : "border-border-c bg-inner-box text-text-secondary",
      ].join(" ")}
    >
      {children}
    </span>
  );
}
