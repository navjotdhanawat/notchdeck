"use client";

import { Section } from "@/components/ui/Section";
import { Button } from "@/components/ui/Button";

// Replace these with real LemonSqueezy checkout URLs after setup
const BUY_PERSONAL_URL = "#buy-personal";
const BUY_UPDATES_URL = "#buy-updates";
const BUY_TEAMS_URL = "#buy-teams";
const DOWNLOAD_URL = "#download";

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

const CROSS = (
  <svg
    aria-hidden
    width="14"
    height="14"
    viewBox="0 0 14 14"
    fill="none"
    className="mt-[2px] shrink-0 opacity-25"
  >
    <path
      d="M3.5 3.5L10.5 10.5M10.5 3.5L3.5 10.5"
      stroke="currentColor"
      strokeWidth="1.75"
      strokeLinecap="round"
    />
  </svg>
);

function Feature({ included, children }: { included: boolean; children: string }) {
  return (
    <li className="flex items-start gap-2 text-[13.5px] leading-snug text-text-secondary">
      {included ? CHECK : CROSS}
      <span className={included ? "text-text-primary" : ""}>{children}</span>
    </li>
  );
}

export function Pricing() {
  return (
    <Section id="pricing" num="07" title="Simple pricing">
      <div className="grid gap-5 md:grid-cols-3">

        {/* --- Free Trial --- */}
        <div className="flex flex-col gap-6 rounded-xl border border-border-c bg-surface-top p-6">
          <div>
            <p className="font-mono text-[11px] uppercase tracking-wider text-text-secondary">
              Free trial
            </p>
            <p className="mt-2 font-serif text-4xl font-normal text-text-primary">
              $0
            </p>
            <p className="mt-1 text-[13px] text-text-secondary">
              7 days, full access · no card required
            </p>
          </div>

          <ul className="flex flex-col gap-3">
            <Feature included>All current features unlocked</Feature>
            <Feature included>Claude Code + all agents</Feature>
            <Feature included>Act-in-place decisions</Feature>
            <Feature included>Cost tracking &amp; themes</Feature>
            <Feature included>Session history</Feature>
          </ul>

          <div className="mt-auto">
            <Button variant="ghost" href={DOWNLOAD_URL} className="w-full text-[13px]">
              Start free trial
            </Button>
            <p className="mt-2 text-center text-[11px] text-text-secondary">
              Downgrades automatically after 7 days
            </p>
          </div>
        </div>

        {/* --- Personal --- */}
        <div className="flex flex-col gap-6 rounded-xl border border-border-c bg-surface-top p-6">
          <div>
            <p className="font-mono text-[11px] uppercase tracking-wider text-text-secondary">
              Personal
            </p>
            <p className="mt-2 font-serif text-4xl font-normal text-text-primary">
              $9.99
            </p>
            <p className="mt-1 text-[13px] text-text-secondary">
              One-time · yours forever
            </p>
          </div>

          <ul className="flex flex-col gap-3">
            <Feature included>Everything in Free trial</Feature>
            <Feature included>Claude Code + all agents</Feature>
            <Feature included>Act-in-place decisions</Feature>
            <Feature included>Cost tracking &amp; themes</Feature>
            <Feature included>Session history</Feature>
            <Feature included={false}>Future major version updates</Feature>
          </ul>

          <div className="mt-auto">
            <Button variant="ghost" href={BUY_PERSONAL_URL} className="w-full text-[13px]">
              Buy Personal
            </Button>
            <p className="mt-2 text-center text-[11px] text-text-secondary">
              Single Mac · instant license key
            </p>
          </div>
        </div>

        {/* --- Personal + Updates (most popular) --- */}
        <div className="relative flex flex-col gap-6 rounded-xl border border-accent/40 bg-surface-top p-6 shadow-[0_0_40px_-12px_var(--accent)]">
          {/* Badge */}
          <span className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full border border-accent/30 bg-accent px-3 py-0.5 font-mono text-[10px] uppercase tracking-wider text-on-accent">
            Most popular
          </span>

          <div>
            <p className="font-mono text-[11px] uppercase tracking-wider text-text-secondary">
              Personal + Updates
            </p>
            <p className="mt-2 font-serif text-4xl font-normal text-text-primary">
              $14.99
            </p>
            <p className="mt-1 text-[13px] text-text-secondary">
              One-time · 12 months of major updates
            </p>
          </div>

          <ul className="flex flex-col gap-3">
            <Feature included>Everything in Personal</Feature>
            <Feature included>Claude Code + all agents</Feature>
            <Feature included>Act-in-place decisions</Feature>
            <Feature included>Cost tracking &amp; themes</Feature>
            <Feature included>Session history</Feature>
            <Feature included>12 months of major version updates</Feature>
          </ul>

          <div className="mt-auto">
            <Button variant="primary" href={BUY_UPDATES_URL} className="w-full text-[13px]">
              Buy Personal + Updates
            </Button>
            <p className="mt-2 text-center text-[11px] text-text-secondary">
              Single Mac · instant license key
            </p>
          </div>
        </div>
      </div>

      {/* Teams row */}
      <div className="mt-5 flex flex-col items-center justify-between gap-4 rounded-xl border border-border-c bg-surface-top px-6 py-5 sm:flex-row">
        <div>
          <p className="font-mono text-[11px] uppercase tracking-wider text-text-secondary">
            Teams · 3 seats
          </p>
          <p className="mt-1 text-[15px] font-semibold text-text-primary">
            <span className="mr-2 text-text-secondary line-through opacity-50">$29.99</span>
            $19.99
            <span className="ml-2 rounded-md bg-accent/15 px-2 py-0.5 font-mono text-[10px] uppercase tracking-wide text-accent">
              Launch offer
            </span>
          </p>
          <p className="mt-0.5 text-[13px] text-text-secondary">
            One license key covers 3 Macs · SSH remote &amp; team features coming
          </p>
        </div>
        <Button variant="ghost" href={BUY_TEAMS_URL} className="shrink-0 text-[13px]">
          Buy Teams
        </Button>
      </div>

      {/* Footer note */}
      <p className="mt-6 text-center text-[12px] text-text-secondary">
        All prices in USD · no subscription · no renewal required · one-time purchase
      </p>
    </Section>
  );
}
