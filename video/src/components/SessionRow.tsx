import React from "react";
import type { Palette, Session, SessionState } from "../types";

const SYS =
  "-apple-system,BlinkMacSystemFont,'SF Pro Text','Helvetica Neue',Arial,sans-serif";

const STATE_COLOR = (s: SessionState, p: Palette): string => {
  const map: Record<SessionState, string> = {
    working: p.working,
    needsPermission: p.needsPermission,
    needsInput: p.needsInputDot,
    done: p.done,
    failed: p.failed,
  };
  return map[s];
};

const AGENT_COLOR = (a: Session["agent"], p: Palette): string => {
  const map = {
    claude: p.agentClaude,
    codex: p.agentCodex,
    gemini: p.agentGemini,
  };
  return map[a];
};

const agentLabel = (a: Session["agent"]) => a[0].toUpperCase() + a.slice(1);

const elapsed = (min: number): string => {
  if (min < 60) return `${min}m`;
  return `${Math.floor(min / 60)}h ${min % 60}m`;
};

export function SessionRow({
  session,
  p,
  opacity = 1,
}: {
  session: Session;
  p: Palette;
  opacity?: number;
}) {
  const dotColor = STATE_COLOR(session.state, p);
  const agentColor = AGENT_COLOR(session.agent, p);

  return (
    <div
      style={{
        display: "flex",
        alignItems: "flex-start",
        gap: 10,
        padding: "7px 0",
        borderBottom: `1px solid ${p.border}`,
        fontFamily: SYS,
        opacity,
      }}
    >
      {/* State dot */}
      <div
        style={{
          width: 8,
          height: 8,
          borderRadius: "50%",
          background: dotColor,
          flexShrink: 0,
          marginTop: 5,
          boxShadow: `0 0 6px ${dotColor}`,
        }}
      />

      {/* Title + activity */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            fontSize: 13,
            fontWeight: 600,
            color: p.textPrimary,
            whiteSpace: "nowrap",
            overflow: "hidden",
            textOverflow: "ellipsis",
          }}
        >
          {session.title}
        </div>
        <div
          style={{
            fontSize: 11,
            color: dotColor,
            marginTop: 2,
            whiteSpace: "nowrap",
            overflow: "hidden",
            textOverflow: "ellipsis",
          }}
        >
          {session.activity}
        </div>
      </div>

      {/* Right: agent badge + elapsed */}
      <div
        style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 4, flexShrink: 0 }}
      >
        <div
          style={{
            fontSize: 10,
            fontWeight: 600,
            color: agentColor,
            background: `${agentColor}22`,
            borderRadius: 4,
            padding: "1px 5px",
          }}
        >
          {agentLabel(session.agent)}
        </div>
        <div
          style={{
            fontSize: 10,
            color: p.textSecondary,
            fontVariantNumeric: "tabular-nums",
          }}
        >
          {elapsed(session.elapsedMin)}
        </div>
      </div>
    </div>
  );
}
