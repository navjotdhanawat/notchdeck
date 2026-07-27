import React from "react";
import type { Palette, Session } from "../types";

const SYS =
  "-apple-system,BlinkMacSystemFont,'SF Pro Text','Helvetica Neue',Arial,sans-serif";

export function PermissionCard({
  session,
  p,
  showButtons = true,
}: {
  session: Session;
  p: Palette;
  showButtons?: boolean;
}) {
  const act = session.act;
  if (!act) return null;

  return (
    <div
      style={{
        fontFamily: SYS,
        background: p.innerBox,
        border: `1px solid ${p.border}`,
        borderRadius: 12,
        padding: "12px 14px",
        marginTop: 8,
      }}
    >
      {/* Header */}
      <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 10 }}>
        <span
          style={{
            width: 8,
            height: 8,
            borderRadius: "50%",
            background: p.needsPermission,
            boxShadow: `0 0 6px ${p.needsPermission}`,
            flexShrink: 0,
            display: "block",
          }}
        />
        <span style={{ fontSize: 11.5, fontWeight: 600, color: p.needsPermission }}>
          Permission Required
        </span>
        <span
          style={{
            marginLeft: "auto",
            fontSize: 10,
            color: p.textSecondary,
            background: `${p.agentCodex}22`,
            color: p.agentCodex,
            borderRadius: 4,
            padding: "1px 5px",
            fontWeight: 600,
          }}
        >
          Codex
        </span>
      </div>

      {/* File info */}
      <div style={{ fontSize: 11, color: p.textSecondary, marginBottom: 8 }}>
        Wants to edit{" "}
        <span
          style={{
            fontFamily: "monospace",
            color: p.textPrimary,
            background: "rgba(255,255,255,0.06)",
            borderRadius: 3,
            padding: "1px 4px",
          }}
        >
          {act.file ?? "middleware.ts"}
        </span>
      </div>

      {/* Diff preview */}
      {act.diff && (
        <div
          style={{
            fontFamily: "monospace",
            fontSize: 10.5,
            lineHeight: 1.6,
            background: "rgba(0,0,0,0.3)",
            borderRadius: 6,
            padding: "8px 10px",
            marginBottom: 10,
            border: `1px solid ${p.border}`,
          }}
        >
          {act.diff.map((line, i) => (
            <div
              key={i}
              style={{
                color:
                  line.type === "add"
                    ? p.done
                    : line.type === "del"
                    ? p.failed
                    : p.textSecondary,
                background:
                  line.type === "add"
                    ? `${p.done}18`
                    : line.type === "del"
                    ? `${p.failed}18`
                    : "transparent",
                paddingLeft: 4,
                whiteSpace: "pre",
              }}
            >
              {line.type === "add" ? "+" : line.type === "del" ? "−" : " "}
              {"  "}
              {line.text}
            </div>
          ))}
        </div>
      )}

      {/* Buttons */}
      {showButtons && (
        <div style={{ display: "flex", gap: 8 }}>
          <div
            style={{
              flex: 1,
              textAlign: "center",
              padding: "6px 0",
              borderRadius: 7,
              fontSize: 12,
              fontWeight: 600,
              background: p.done,
              color: "#000",
              cursor: "default",
            }}
          >
            Allow
          </div>
          <div
            style={{
              flex: 1,
              textAlign: "center",
              padding: "6px 0",
              borderRadius: 7,
              fontSize: 12,
              fontWeight: 600,
              background: "rgba(255,255,255,0.08)",
              color: p.textPrimary,
              border: `1px solid ${p.border}`,
              cursor: "default",
            }}
          >
            Deny
          </div>
        </div>
      )}
    </div>
  );
}
