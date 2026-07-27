"use client";

import Link from "next/link";

export default function NotFound() {
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
        404
      </span>
      <h1 style={{ fontSize: "1.5rem", fontWeight: 600, margin: 0 }}>Page not found</h1>
      <p style={{ fontSize: "0.875rem", opacity: 0.5, margin: 0 }}>
        The page you&apos;re looking for doesn&apos;t exist.
      </p>
      <Link
        href="/"
        style={{
          marginTop: "0.5rem",
          fontSize: "0.875rem",
          color: "var(--accent, #00d9ff)",
          textDecoration: "underline",
          textUnderlineOffset: "3px",
        }}
      >
        ← Back to NotchDeck
      </Link>
    </div>
  );
}
