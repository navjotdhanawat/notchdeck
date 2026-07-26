"use client";

import { Button } from "@/components/ui/Button";

const INSTALL_CMD = `curl -fsSL https://install.notchdeck.com | bash`;

export function CTA() {
  return (
    <section
      id="download"
      className="mx-auto w-full max-w-[1120px] px-6 py-20 sm:py-28"
    >
      <div className="flex flex-col items-center text-center">
        <h2
          style={{ fontFamily: "var(--font-serif)" }}
          className="text-[clamp(36px,7vw,58px)] font-normal leading-tight tracking-[-0.01em] text-text-primary"
        >
          Put it in your notch.
        </h2>

        <p className="mt-4 max-w-[480px] text-[14px] leading-relaxed text-text-secondary">
          One command installs NotchDeck and auto-configures your agent hooks.
          No account. No cloud. 7-day full trial, then{" "}
          <span className="text-text-primary">$9.99</span> to keep it.
        </p>

        {/* Install command */}
        <div className="mt-8 flex w-full max-w-[520px] items-center gap-3 rounded-xl border border-border-c bg-surface-top px-4 py-3">
          <span className="select-none font-mono text-[13px] text-text-secondary/50">$</span>
          <code className="flex-1 text-left font-mono text-[13px] text-text-primary">
            {INSTALL_CMD.replace(/^\$ /, "")}
          </code>
          <button
            type="button"
            onClick={() => navigator.clipboard?.writeText(INSTALL_CMD)}
            className="shrink-0 rounded-md border border-border-c px-2.5 py-1 font-mono text-[11px] text-text-secondary transition-colors hover:border-white/20 hover:text-text-primary"
          >
            copy
          </button>
        </div>

        <div className="mt-5 flex flex-wrap items-center justify-center gap-3">
          <Button variant="primary" href="#pricing" className="text-[14px]">
            See pricing
          </Button>
          <Button variant="ghost" href="#pricing" className="text-[14px]">
            Start free trial
          </Button>
        </div>

        <p className="mt-5 text-[12px] text-text-secondary">
          Apple Silicon · macOS 14+ · iTerm2 / WezTerm / Kitty · Claude Code · Codex
        </p>
        <p className="mt-2 text-[11px] text-text-secondary/50">
          Right-click → Open on first launch (app is unsigned while in early access)
        </p>
      </div>
    </section>
  );
}
