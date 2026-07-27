import React from "react";
import type { Palette, Session } from "../types";
import { SessionRow } from "./SessionRow";

const SYS =
  "-apple-system,BlinkMacSystemFont,'SF Pro Text','Helvetica Neue',Arial,sans-serif";

export function NotchPanel({
  sessions,
  p,
  tokens,
  cost,
  children,
}: {
  sessions: Session[];
  p: Palette;
  tokens?: string;
  cost?: string;
  children?: React.ReactNode;
}) {
  const C = 12;

  return (
    <div style={{ position: "relative", marginLeft: "auto", marginRight: "auto", width: 406 }}>
      {/* Left concave ear */}
      <div
        style={{
          pointerEvents: "none",
          position: "absolute",
          top: 0,
          left: -C,
          width: C,
          height: C,
          zIndex: 10,
          background: `radial-gradient(circle at 0% 100%, transparent ${C - 1}px, ${p.surfaceBottom} ${C}px)`,
        }}
      />
      {/* Right concave ear */}
      <div
        style={{
          pointerEvents: "none",
          position: "absolute",
          top: 0,
          right: -C,
          width: C,
          height: C,
          zIndex: 10,
          background: `radial-gradient(circle at 100% 100%, transparent ${C - 1}px, ${p.surfaceBottom} ${C}px)`,
        }}
      />

      {/* Panel body */}
      <div
        style={{
          position: "relative",
          width: "100%",
          borderBottomLeftRadius: 26,
          borderBottomRightRadius: 26,
          background: p.surfaceBottom,
          paddingTop: 32,
          boxShadow: "0 28px 55px -14px rgba(0,0,0,0.8), 0 0 0 0.5px rgba(255,255,255,0.06)",
          fontFamily: SYS,
        }}
      >
        {/* Header */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 16,
            borderBottom: `1px solid ${p.border}`,
            padding: "10px 14px 11px",
          }}
        >
          <span style={{ fontSize: 13, color: p.accent, filter: "drop-shadow(0 0 6px currentColor)" }}>
            ✦
          </span>
          <span style={{ fontSize: 12, color: p.textSecondary }}>
            {sessions.length} active
          </span>
          {tokens && cost && (
            <span
              style={{
                marginLeft: "auto",
                fontFamily: "monospace",
                fontSize: 11,
                color: p.textSecondary,
                fontVariantNumeric: "tabular-nums",
              }}
            >
              {tokens} tok ·{" "}
              <strong style={{ color: p.textPrimary }}>{cost}</strong>
            </span>
          )}
        </div>

        {/* Sessions */}
        <div style={{ position: "relative", padding: "12px 14px 16px" }}>
          {sessions.map((s) => (
            <SessionRow key={s.id} session={s} p={p} />
          ))}
          {sessions.length === 0 && (
            <div
              style={{
                textAlign: "center",
                padding: "24px 8px",
                fontSize: 12,
                color: p.textSecondary,
              }}
            >
              No active sessions
            </div>
          )}
          {children}
        </div>
      </div>
    </div>
  );
}
