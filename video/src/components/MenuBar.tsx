import React from "react";
import type { Palette } from "../types";

const SYS =
  "-apple-system,BlinkMacSystemFont,'SF Pro Text','Helvetica Neue',Arial,sans-serif";

const LIGHTS = ["#ff5f57", "#febc2e", "#28c840"];

export function MenuBar({ p }: { p: Palette }) {
  return (
    <div
      style={{
        fontFamily: SYS,
        position: "relative",
        zIndex: 0,
        display: "flex",
        height: 32,
        alignItems: "center",
        justifyContent: "space-between",
        background: "rgba(0,0,0,0.25)",
        padding: "0 13px",
        fontSize: 12.5,
        color: p.textPrimary,
      }}
    >
      {/* Left menus */}
      <div style={{ display: "flex", alignItems: "center", gap: 15 }}>
        <span style={{ fontSize: 13.5 }}>⌘</span>
        <span style={{ fontWeight: 600 }}>iTerm2</span>
        <span style={{ color: p.textSecondary }}>Shell</span>
        <span style={{ color: p.textSecondary }}>Edit</span>
        <span style={{ color: p.textSecondary }}>View</span>
        <span style={{ color: p.textSecondary }}>Window</span>
      </div>

      {/* Camera island */}
      <div
        style={{
          position: "absolute",
          left: "50%",
          top: 0,
          transform: "translateX(-50%)",
          pointerEvents: "none",
        }}
      >
        <div
          style={{
            height: 32,
            width: 130,
            background: p.surfaceBottom,
            position: "relative",
          }}
        >
          <span
            style={{
              position: "absolute",
              left: "50%",
              top: "50%",
              transform: "translate(-50%, -50%)",
              width: 6,
              height: 6,
              borderRadius: "50%",
              background:
                "radial-gradient(circle at 35% 30%, #26324d, #000 70%)",
              boxShadow: "0 0 0 1px rgba(255,255,255,0.06)",
              display: "block",
            }}
          />
        </div>
      </div>

      {/* Right status */}
      <div style={{ display: "flex", alignItems: "center", gap: 13 }}>
        <span style={{ fontSize: 11, color: p.textSecondary }}>
          {new Date().toLocaleTimeString("en-US", {
            hour: "numeric",
            minute: "2-digit",
          })}
        </span>
      </div>
    </div>
  );
}
