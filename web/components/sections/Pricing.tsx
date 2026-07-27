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

export function Pricing() {
  return (
    <Section id="pricing" num="07" title="Simple pricing">
      <div className="grid gap-5 md:grid-cols-2 max-w-[720px] mx-auto">

        {/* --- Free (v1) --- */}
        <div className="flex flex-col gap-6 rounded-xl border border-accent/40 bg-surface-top p-6 shadow-[0_0_40px_-12px_var(--accent)]">
          <span className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full border border-accent/30 bg-accent px-3 py-0.5 font-mono text-[10px] uppercase tracking-wider text-on-accent hidden" />
          <div>
            <p className="font-mono text-[11px] uppercase tracking-wider text-text-secondary">
              Free · v1
            </p>
            <p className="mt-2 font-serif text-4xl font-normal text-text-primary">
              $0
            </p>
            <p className="mt-1 text-[13px] text-text-secondary">
              Everything, forever · no card, no trial, no catch
            </p>
          </div>

          <ul className="flex flex-col gap-3">
            <Feature>All current features unlocked</Feature>
            <Feature>Claude Code + Codex + all agents</Feature>
            <Feature>Act-in-place decisions</Feature>
            <Feature>Cost tracking &amp; 10 themes</Feature>
            <Feature>Session history</Feature>
            <Feature>No telemetry · fully local</Feature>
          </ul>

          <div className="mt-auto">
            <Button variant="primary" href="#download" className="w-full text-[13px]">
              Download for macOS
            </Button>
            <p className="mt-2 text-center text-[11px] text-text-secondary">
              Apple Silicon · macOS 14+
            </p>
          </div>
        </div>

        {/* --- Pro (coming soon) --- */}
        <div className="flex flex-col gap-6 rounded-xl border border-border-c bg-surface-top p-6">
          <div>
            <div className="flex items-center gap-2">
              <p className="font-mono text-[11px] uppercase tracking-wider text-text-secondary">
                Pro
              </p>
              <span className="rounded-md bg-surface-raised px-2 py-0.5 font-mono text-[10px] uppercase tracking-wide text-text-secondary">
                Coming soon
              </span>
            </div>
            <p className="mt-2 font-serif text-4xl font-normal text-text-primary">
              TBD
            </p>
            <p className="mt-1 text-[13px] text-text-secondary">
              Early supporters get it free — see below
            </p>
          </div>

          <ul className="flex flex-col gap-3">
            <Feature>Everything in Free</Feature>
            <Feature>SSH remote agent monitoring</Feature>
            <Feature>Team seats &amp; shared sessions</Feature>
            <Feature>Mobile relay (phone notifications)</Feature>
            <Feature>Priority support</Feature>
            <Feature>All future major version updates</Feature>
          </ul>

          <div className="mt-auto">
            <Button variant="ghost" href="#waitlist" className="w-full text-[13px]">
              Join waitlist
            </Button>
            <p className="mt-2 text-center text-[11px] text-text-secondary">
              Get notified when Pro launches
            </p>
          </div>
        </div>
      </div>

      {/* Giveaway banner */}
      <div className="mt-5 flex flex-col items-center justify-between gap-4 rounded-xl border border-border-c bg-surface-top px-6 py-5 sm:flex-row">
        <div>
          <p className="font-mono text-[11px] uppercase tracking-wider text-text-secondary">
            Get Pro free
          </p>
          <p className="mt-1 text-[15px] font-semibold text-text-primary">
            Post NotchDeck on{" "}
            <span className="text-accent">𝕏 (Twitter)</span> and get 100+ likes
          </p>
          <p className="mt-0.5 text-[13px] text-text-secondary">
            DM{" "}
            <a
              href="https://x.com/navjotdhanawat"
              target="_blank"
              rel="noopener noreferrer"
              className="text-text-primary underline underline-offset-2 hover:text-accent transition-colors"
            >
              @navjotdhanawat
            </a>{" "}
            with a link to your post — we&apos;ll send you a Pro key manually.
          </p>
        </div>
        <a
          href="https://x.com/intent/tweet?text=Just%20discovered%20NotchDeck%20%E2%80%94%20puts%20your%20AI%20agent%20sessions%20right%20in%20the%20MacBook%20notch.%20Claude%20Code%2C%20Codex%2C%20act-in-place%20decisions%2C%20all%20free.%20notchdeck.com"
          target="_blank"
          rel="noopener noreferrer"
          className="shrink-0 rounded-lg border border-border-c bg-surface-raised px-4 py-2 font-mono text-[13px] text-text-primary transition-colors hover:border-white/20 hover:text-accent"
        >
          Share on 𝕏
        </a>
      </div>

      <p className="mt-6 text-center text-[12px] text-text-secondary">
        v1 is fully free · paid Pro comes later · no bait-and-switch
      </p>
    </Section>
  );
}
