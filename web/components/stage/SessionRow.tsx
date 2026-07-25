"use client";
import { motion, useReducedMotion } from "motion/react";
import type { AgentId, Session, SessionState } from "@/lib/types";
import { Badge } from "@/components/ui/Badge";

/** Notch/panel body reads as native macOS, not the page serif. */
const SYS =
  "-apple-system,BlinkMacSystemFont,'SF Pro Text','Helvetica Neue',Arial,sans-serif";

/**
 * State → the text-token that drives BOTH the state dot (via `currentColor`) and
 * the activity line. `needsInput` uses the dedicated needs-input-dot token; the
 * other four map straight onto their `st-*` tokens.
 */
const STATE_TINT: Record<SessionState, string> = {
  working: "text-st-working",
  needsPermission: "text-st-perm",
  needsInput: "text-needs-input-dot",
  done: "text-st-done",
  failed: "text-st-failed",
};

const agentLabel = (a: AgentId) => a[0].toUpperCase() + a.slice(1);

/** 27m / 1h / 5h — minutes under an hour, whole hours above. */
function fmtElapsed(min: number): string {
  return min < 60 ? `${min}m` : `${Math.floor(min / 60)}h`;
}

/**
 * One session, one row. Renders a live state dot (pulsing while `working`,
 * gated by reduced-motion), the title, an activity line, agent + terminal
 * badges, and elapsed time. Clickable / keyboard-focusable when `onJump` is
 * given; `layout` (also reduced-motion gated) lets the list reflow smoothly as
 * states change. `compact` collapses to a single line (no activity).
 */
export function SessionRow({
  session,
  compact = false,
  onJump,
}: {
  session: Session;
  compact?: boolean;
  onJump?: (id: string) => void;
}) {
  const reduce = useReducedMotion();
  const tint = STATE_TINT[session.state];
  const isWorking = session.state === "working";
  const clickable = !!onJump;

  const activate = () => onJump?.(session.id);
  const onKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      activate();
    }
  };

  const badges = (
    <>
      <Badge kind={session.agent}>{agentLabel(session.agent)}</Badge>
      <Badge>{session.terminal}</Badge>
    </>
  );
  const elapsed = (
    <span className="font-mono text-[11px] tabular-nums text-text-secondary">
      {fmtElapsed(session.elapsedMin)}
    </span>
  );

  return (
    <motion.div
      layout={!reduce}
      initial={reduce ? false : { opacity: 0, y: -6 }}
      animate={reduce ? undefined : { opacity: 1, y: 0 }}
      exit={reduce ? undefined : { opacity: 0, y: -6 }}
      transition={{ duration: 0.22, ease: "easeOut" }}
      role={clickable ? "button" : undefined}
      tabIndex={clickable ? 0 : undefined}
      aria-label={clickable ? `Jump to ${session.title}` : undefined}
      onClick={clickable ? activate : undefined}
      onKeyDown={clickable ? onKeyDown : undefined}
      style={{ fontFamily: SYS }}
      className={[
        "flex h-[36px] items-center gap-[11px] rounded-xl px-2 transition-colors",
        clickable ? "cursor-pointer" : "cursor-default",
        "hover:bg-white/[0.06] focus:outline-none focus-visible:ring-2 focus-visible:ring-accent/70",
      ].join(" ")}
    >
      {/* live state dot — glow + pulse come from the state tint */}
      <motion.span
        aria-hidden
        className={`${tint} mx-[3px] flex-none rounded-full bg-current`}
        style={{
          width: 9,
          height: 9,
          marginTop: compact ? 0 : 5,
          boxShadow: "0 0 8px currentColor",
        }}
        animate={
          isWorking && !reduce
            ? { opacity: [1, 0.4, 1], scale: [1, 0.82, 1] }
            : { opacity: 1, scale: 1 }
        }
        transition={
          isWorking && !reduce
            ? { duration: 1.4, repeat: Infinity, ease: "easeInOut" }
            : { duration: 0 }
        }
      />

      {compact ? (
        <>
          <span className="min-w-0 flex-1 truncate text-[13.5px] font-medium text-text-primary">
            {session.title}
          </span>
          <div className="flex flex-none items-center gap-[9px]">
            {badges}
            {elapsed}
          </div>
        </>
      ) : (
        <>
          <div className="min-w-0 flex-1">
            <div className="truncate text-[15px] font-semibold leading-tight text-text-primary">
              {session.title}
            </div>
            <div className={`mt-[3px] truncate text-[12px] font-medium ${tint}`}>
              {session.activity}
            </div>
          </div>
          <div className="flex flex-none flex-col items-end gap-[6px]">
            <div className="flex gap-[6px]">{badges}</div>
            {elapsed}
          </div>
        </>
      )}
    </motion.div>
  );
}
