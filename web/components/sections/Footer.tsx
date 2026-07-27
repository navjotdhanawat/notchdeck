"use client";

import { WaitlistInline } from "@/components/sections/Waitlist";

export function Footer() {
  return (
    <footer className="w-full border-t border-white/[0.04] bg-surface-bottom/50 py-12">
      <div className="mx-auto max-w-[1120px] px-6">
        <div className="flex flex-col gap-8 sm:flex-row sm:items-start sm:justify-between">
          {/* Left: ethos */}
          <div className="max-w-sm text-[13px] leading-relaxed text-text-secondary">
            <p>
              <strong className="font-semibold text-text-primary">Local-only.</strong>{" "}
              No cloud, no telemetry, no yabai. Your sessions stay on your machine.
            </p>
            <p className="mt-3">
              Built on{" "}
              <a
                href="https://github.com/MrKai77/DynamicNotchKit"
                target="_blank"
                rel="noopener noreferrer"
                className="text-accent underline decoration-accent/40 underline-offset-2 transition-colors hover:decoration-accent"
              >
                DynamicNotchKit
              </a>{" "}
              by MrKai77.
            </p>
          </div>

          {/* Center: waitlist */}
          <WaitlistInline />

          {/* Right: links */}
          <div className="flex flex-wrap gap-x-6 gap-y-2 text-[13px] text-text-secondary">
            <a
              href="https://github.com/navjotdhanawat/notchdeck"
              target="_blank"
              rel="noopener noreferrer"
              className="transition-colors hover:text-text-primary"
            >
              GitHub
            </a>
            <a
              href="https://buymeacoffee.com/navjotdhanawat"
              target="_blank"
              rel="noopener noreferrer"
              className="transition-colors hover:text-text-primary"
            >
              Sponsor
            </a>
            <a href="#support" className="transition-colors hover:text-text-primary">
              Support
            </a>
            <a
              href="mailto:nav@notchdeck.com"
              className="transition-colors hover:text-text-primary"
            >
              Contact
            </a>
          </div>
        </div>

        <p className="mt-8 text-[12px] text-text-secondary/40">
          © {new Date().getFullYear()} NotchDeck · Made for developers who run parallel agents
        </p>
      </div>
    </footer>
  );
}
