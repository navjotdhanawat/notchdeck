"use client";

import { useEffect } from "react";

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <div
      style={{
        minHeight: "100dvh",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        gap: "1rem",
        fontFamily: "var(--font-mono, monospace)",
        background: "#000",
        color: "#fff",
        textAlign: "center",
        padding: "2rem",
      }}
    >
      <span style={{ fontSize: "0.75rem", letterSpacing: "0.15em", opacity: 0.5, textTransform: "uppercase" }}>
        Error
      </span>
      <h2 style={{ fontSize: "1.5rem", fontWeight: 600, margin: 0 }}>Something went wrong</h2>
      <p style={{ fontSize: "0.875rem", opacity: 0.5, margin: 0 }}>
        An unexpected error occurred. Please try again.
      </p>
      <button
        onClick={reset}
        style={{
          marginTop: "0.5rem",
          fontSize: "0.875rem",
          color: "var(--accent, #00d9ff)",
          background: "none",
          border: "none",
          cursor: "pointer",
          textDecoration: "underline",
          textUnderlineOffset: "3px",
        }}
      >
        Try again
      </button>
    </div>
  );
}
