import React from "react";
import type { Palette } from "../types";

const SYS =
  "-apple-system,BlinkMacSystemFont,'SF Pro Text','Helvetica Neue',Arial,sans-serif";

const LIGHTS = ["#ff5f57", "#febc2e", "#28c840"];

export function TerminalWindow({
  title,
  lines,
  p,
  focused = false,
}: {
  title: string;
  lines: string[];
  p: Palette;
  focused?: boolean;
}) {
  return (
    <div
      style={{
        borderRadius: 12,
        border: `1px solid ${focused ? p.accent : p.border}`,
        background: p.surfaceBottom,
        overflow: "hidden",
        boxShadow: focused
          ? `0 0 0 2px ${p.accent}, 0 0 30px -6px ${p.accent}`
          : "none",
        transition: "box-shadow 0.5s ease, border-color 0.5s ease",
      }}
    >
      {/* Title bar */}
      <div
        style={{
          fontFamily: SYS,
          display: "flex",
          alignItems: "center",
          height: 28,
          gap: 7,
          borderBottom: `1px solid ${p.border}`,
          background: "rgba(255,255,255,0.04)",
          padding: "0 12px",
        }}
      >
        {LIGHTS.map((c) => (
          <span
            key={c}
            style={{
              width: 11,
              height: 11,
              borderRadius: "50%",
              background: c,
              flexShrink: 0,
              display: "block",
            }}
          />
        ))}
        <span
          style={{
            marginLeft: 8,
            fontSize: 11.5,
            color: p.textSecondary,
            overflow: "hidden",
            textOverflow: "ellipsis",
            whiteSpace: "nowrap",
          }}
        >
          {title}
        </span>
      </div>

      {/* Body */}
      <div
        style={{
          padding: "11px 14px",
          fontSize: 11.5,
          lineHeight: 1.7,
          color: p.textSecondary,
          fontFamily: "monospace",
        }}
      >
        {lines.map((line, i) => (
          <div key={i} style={{ whiteSpace: "pre-wrap" }}>
            {line}
          </div>
        ))}
      </div>
    </div>
  );
}
