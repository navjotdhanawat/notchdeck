/**
 * Status chip — solid when `on` (shipping), dashed/muted when not (via seam/soon).
 * Used in the AgentsTerminals marketing section to show shipping vs. planned support.
 */
export function Chip({ on = false, children }: { on?: boolean; children: React.ReactNode }) {
  return (
    <span
      className={[
        "inline-flex items-center whitespace-nowrap rounded-md px-[9px] py-[4px] font-mono text-[11px] leading-none",
        on
          ? "border-2 border-border-c bg-inner-box text-text-primary"
          : "border-2 border-dashed border-border-c/50 bg-transparent text-text-secondary/60",
      ].join(" ")}
    >
      {children}
    </span>
  );
}
