"use client";
import { AnimatePresence } from "motion/react";
import type { Session } from "@/lib/types";
import { SessionRow } from "@/components/stage/SessionRow";

/** Notch/panel body reads as native macOS, not the page serif. */
const SYS =
  "-apple-system,BlinkMacSystemFont,'SF Pro Text','Helvetica Neue',Arial,sans-serif";

/** Aggregate usage across active sessions — tokens + cost only (spec §8). */
export interface NotchUsage {
  /** Pre-formatted token count, e.g. "1.2M". */
  tokens: string;
  /** Pre-formatted cost, e.g. "$2.14". */
  cost: string;
}

/**
 * The notch panel: a rounded-bottom dark surface descending from the notch,
 * a usage header ("N active · tok · $"), then one `SessionRow` per session
 * (first rich, the rest compact) inside an `AnimatePresence` so rows enter,
 * exit, and reflow smoothly. `children` is an overlay slot for the act card
 * (Task 5). All surfaces/colors are theme tokens, so themes recolor the panel.
 */
export function Notch({
  sessions,
  usage,
  onJump,
  children,
}: {
  sessions: Session[];
  usage?: NotchUsage;
  onJump?: (id: string) => void;
  children?: React.ReactNode;
}) {
  return (
    <div
      className="relative mx-auto w-[406px] max-w-full rounded-b-[26px] bg-surface-bottom pt-[30px] shadow-[0_28px_55px_-14px_rgba(0,0,0,0.8),0_0_0_0.5px_rgba(255,255,255,0.06)]"
    >
      {/* usage header */}
      <div
        style={{ fontFamily: SYS }}
        className="flex items-center gap-4 border-b border-border-c px-[14px] pb-[11px] pt-[8px]"
      >
        <span
          aria-hidden
          className="text-[13px] text-accent"
          style={{ filter: "drop-shadow(0 0 6px currentColor)" }}
        >
          ✦
        </span>
        <span className="text-[12px] text-text-secondary">
          {sessions.length} active
        </span>
        {usage && (
          <span className="ml-auto font-mono text-[11px] tabular-nums text-text-secondary">
            {usage.tokens} tok ·{" "}
            <b className="font-semibold text-text-primary">{usage.cost}</b>
          </span>
        )}
      </div>

      {/* session list + act-card overlay slot */}
      <div className="relative px-[14px] pb-[16px] pt-[12px]">
        <AnimatePresence initial={false}>
          {sessions.map((s, i) => (
            <SessionRow key={s.id} session={s} compact={i !== 0} onJump={onJump} />
          ))}
        </AnimatePresence>
        {sessions.length === 0 && (
          <div
            style={{ fontFamily: SYS }}
            className="px-2 py-6 text-center text-[12px] text-text-secondary"
          >
            No active sessions
          </div>
        )}
        {children}
      </div>
    </div>
  );
}
