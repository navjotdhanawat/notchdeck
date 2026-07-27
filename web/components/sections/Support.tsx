"use client";

import { Section } from "@/components/ui/Section";
import { Button } from "@/components/ui/Button";

const CHECK = (
  <svg
    aria-hidden
    width="14"
    height="14"
    viewBox="0 0 14 14"
    fill="none"
    className="mt-[2px] shrink-0 text-accent"
  >
    <path
      d="M2.5 7L5.5 10L11.5 4"
      stroke="currentColor"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

function Feature({ children }: { children: string }) {
  return (
    <li className="flex items-start gap-2 text-[13.5px] leading-snug text-text-secondary">
      {CHECK}
      <span className="text-text-primary">{children}</span>
    </li>
  );
}

export function Support({ onDownloadClick }: { onDownloadClick: () => void }) {
  return (
    <Section id="support" num="07" title="Support & Open Source">
      <div className="grid gap-5 md:grid-cols-2 max-w-[760px] mx-auto items-stretch">

        {/* --- Free (MIT) --- */}
        <div className="flex flex-col gap-6 rounded-xl border border-accent/40 bg-surface-top p-6 shadow-[0_0_40px_-12px_var(--accent)]">
          <div>
            <p className="font-mono text-[11px] uppercase tracking-wider text-text-secondary">
              Free · MIT License
            </p>
            <p className="mt-2 font-serif text-4xl font-normal text-text-primary">
              $0
            </p>
            <p className="mt-1 text-[13px] text-text-secondary">
              Everything in NotchDeck is 100% free and locally run
            </p>
          </div>

          <ul className="flex flex-col gap-3 flex-1">
            <Feature>All features unlocked</Feature>
            <Feature>Claude Code, Codex, Aider &amp; Gemini</Feature>
            <Feature>Act-in-place decisions in the notch</Feature>
            <Feature>Cost tracking &amp; 10+ themes</Feature>
            <Feature>Session history &amp; local-only logs</Feature>
            <Feature>No telemetry · fully local</Feature>
          </ul>

          <div>
            <Button variant="primary" onClick={onDownloadClick} className="w-full text-[13px]">
              Download for macOS
            </Button>
            <p className="mt-2 text-center text-[11px] text-text-secondary">
              Apple Silicon · macOS 14+
            </p>
          </div>
        </div>

        {/* --- Sponsor (Buy Me a Coffee) --- */}
        <div className="flex flex-col gap-6 rounded-xl border border-border-c bg-surface-top p-6">
          <div>
            <div className="flex items-center gap-2">
              <p className="font-mono text-[11px] uppercase tracking-wider text-accent">
                Sponsor
              </p>
              <span className="rounded-md bg-white/[0.06] px-2 py-0.5 font-mono text-[10px] uppercase tracking-wide text-text-secondary">
                Keep updates coming
              </span>
            </div>
            <p className="mt-2 font-serif text-4xl font-normal text-text-primary">
              Support
            </p>
            <p className="mt-1 text-[13px] text-text-secondary">
              Help cover code-signing certificates and active engineering hours
            </p>
          </div>

          <ul className="flex flex-col gap-3 flex-1">
            <Feature>Covers Apple Developer Program fees ($99/yr) for official codesigning</Feature>
            <Feature>Offsets server, updating infrastructure, and API testing costs</Feature>
            <Feature>Keeps NotchDeck completely independent of VCs, tracking, and Ads</Feature>
            <Feature>Supports active maintenance to keep client terminal hooks stable</Feature>
          </ul>

          <div>
            <Button
              variant="ghost"
              href="https://buymeacoffee.com/navjotdhanawat"
              target="_blank"
              rel="noopener noreferrer"
              className="w-full text-[13px]"
            >
              Buy me a coffee
            </Button>
            <p className="mt-2 text-center text-[11px] text-text-secondary">
              One-time or variable contribution
            </p>
          </div>
        </div>
      </div>

      {/* Share/Promo banner */}
      <div className="mt-5 flex flex-col items-center justify-between gap-4 rounded-xl border border-border-c bg-surface-top px-6 py-5 sm:flex-row">
        <div>
          <p className="font-mono text-[11px] uppercase tracking-wider text-text-secondary">
            Spread the word
          </p>
          <p className="mt-1 text-[15px] font-semibold text-text-primary">
            Help us share <span className="text-accent">NotchDeck</span>
          </p>
          <p className="mt-0.5 text-[13px] text-text-secondary">
            If you like the app, consider posting your experience on 𝕏 (Twitter) or GitHub to help more developers find it.
          </p>
        </div>
        <a
          href="https://x.com/intent/tweet?text=Just%20discovered%20NotchDeck%20%E2%80%94%20puts%20your%20AI%20agent%20sessions%20right%20in%20the%20MacBook%20notch.%20Claude%20Code%2C%20Codex%2C%20act-in-place%20decisions%2C%20all%20free.%20notchdeck.app"
          target="_blank"
          rel="noopener noreferrer"
          className="shrink-0 rounded-lg border border-border-c bg-surface-raised px-4 py-2 font-mono text-[13px] text-text-primary transition-colors hover:border-white/20 hover:text-accent"
        >
          Share on 𝕏
        </a>
      </div>

      <p className="mt-6 text-center text-[12px] text-text-secondary">
        NotchDeck is fully local, private, and open-source under the MIT license
      </p>
    </Section>
  );
}
