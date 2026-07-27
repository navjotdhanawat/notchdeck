"use client";

import { Button } from "@/components/ui/Button";

const GITHUB_URL = "https://github.com/navjotdhanawat/notchdeck/releases";

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
          Download the latest release, double-click to open, and NotchDeck
          auto-configures your agent hooks.{" "}
          <span className="text-text-primary">
            No account. No cloud. Completely free.
          </span>
        </p>

        <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
          <Button variant="primary" href={GITHUB_URL} className="text-[14px]">
            Download for macOS
          </Button>
          <Button variant="ghost" href="#waitlist" className="text-[14px]">
            Join waitlist
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
