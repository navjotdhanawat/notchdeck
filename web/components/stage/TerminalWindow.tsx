/** macOS system stack for the title bar; the body uses the mono token. */
const SYS =
  "-apple-system,BlinkMacSystemFont,'SF Pro Text','Helvetica Neue',Arial,sans-serif";

/** Real macOS traffic-light colors — a platform signifier, kept literal. */
const LIGHTS = ["#ff5f57", "#febc2e", "#28c840"];

/**
 * A terminal window peeking under the notch: traffic lights, a title, and a few
 * sample body lines. `focused` (set by a "jump") flashes a themed accent ring
 * that fades via CSS transition — no JS animation, so it degrades cleanly under
 * prefers-reduced-motion (the global rule snaps the transition off).
 */
export function TerminalWindow({
  title,
  lines,
  focused = false,
}: {
  title: string;
  lines: string[];
  focused?: boolean;
}) {
  return (
    <div
      className={[
        "overflow-hidden rounded-xl border bg-surface-bottom font-mono transition-[box-shadow,border-color] duration-500",
        focused
          ? "border-accent shadow-[0_0_0_2px_var(--accent),0_0_30px_-6px_var(--accent)]"
          : "border-border-c",
      ].join(" ")}
    >
      <div
        style={{ fontFamily: SYS }}
        className="flex h-7 items-center gap-[7px] border-b border-border-c bg-white/[0.04] px-3"
      >
        {LIGHTS.map((c) => (
          <span
            key={c}
            aria-hidden
            className="h-[11px] w-[11px] flex-none rounded-full"
            style={{ background: c }}
          />
        ))}
        <span className="ml-2 truncate text-[11.5px] text-text-secondary">{title}</span>
      </div>
      <div className="px-[14px] py-[11px] text-[11.5px] leading-[1.7] text-text-secondary">
        {lines.map((line, i) => (
          <div key={i} className="whitespace-pre-wrap">
            {line}
          </div>
        ))}
      </div>
    </div>
  );
}
