"use client";
import { AnimatePresence } from "motion/react";
import type { Session } from "@/lib/types";
import { SessionRow } from "@/components/stage/SessionRow";

const SYS =
  "-apple-system,BlinkMacSystemFont,'SF Pro Text','Helvetica Neue',Arial,sans-serif";

export interface NotchUsage {
  tokens: string;
  cost: string;
}

/**
 * The notch panel drops straight down from the top of the stage desktop area
 * (which sits flush below the MenuBar). The two concave "ear" corners sit at
 * top-left and top-right of the panel, creating the characteristic macOS notch
 * shape where the panel meets the menubar.
 *
 * Ear gradient logic (left ear, 12×12px div at -12px from left):
 *   The div occupies the space to the LEFT of the panel's top-left corner.
 *   We want the TOP-RIGHT quadrant of the div to be panel-colored (solid),
 *   and the rest (bottom + left) to be transparent — showing the wallpaper through.
 *   → radial-gradient(circle at 0% 100%, transparent R, color R+1)
 *     Center at bottom-left corner of the ear div, circle grows outward.
 *     Inside the circle (≤R) = transparent; outside (>R) = panel color.
 *   For right ear: mirror → circle at 100% 100%
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
  const C = 12; // concave corner radius in px

  return (
    <div className="relative mx-auto -mt-8 w-[406px] max-w-full">
      {/* Left concave ear */}
      <div
        aria-hidden
        className="pointer-events-none absolute top-0 z-10"
        style={{
          left: -C,
          width: C,
          height: C,
          background: `radial-gradient(circle at 0% 100%, transparent ${C - 1}px, var(--surface-bottom) ${C}px)`,
        }}
      />
      {/* Right concave ear */}
      <div
        aria-hidden
        className="pointer-events-none absolute top-0 z-10"
        style={{
          right: -C,
          width: C,
          height: C,
          background: `radial-gradient(circle at 100% 100%, transparent ${C - 1}px, var(--surface-bottom) ${C}px)`,
        }}
      />

      {/* Panel body — top 32px extends into MenuBar behind camera dot, rounded only at bottom */}
      <div
        className="relative w-full rounded-b-[26px] bg-surface-bottom pt-8 shadow-[0_28px_55px_-14px_rgba(0,0,0,0.8),0_0_0_0.5px_rgba(255,255,255,0.06)]"
        style={{ fontFamily: SYS }}
      >
        {/* usage header */}
        <div className="flex items-center gap-4 border-b border-border-c px-[14px] pb-[11px] pt-[10px]">
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
            {sessions.map((s) => (
              <SessionRow
                key={s.id}
                session={s}
                compact={true}
                onJump={onJump}
              />
            ))}
          </AnimatePresence>
          {sessions.length === 0 && (
            <div className="px-2 py-6 text-center text-[12px] text-text-secondary">
              No active sessions
            </div>
          )}
          {children}
        </div>
      </div>
    </div>
  );
}
