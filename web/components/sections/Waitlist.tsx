"use client";

import { useState } from "react";
import { Section } from "@/components/ui/Section";

async function submitWaitlist(email: string, source: string): Promise<{ ok: boolean; already?: boolean }> {
  const res = await fetch("/api/waitlist", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, source }),
  });
  return res.json();
}

function EmailForm({ source, placeholder = "you@example.com" }: { source: string; placeholder?: string }) {
  const [email, setEmail] = useState("");
  const [state, setState] = useState<"idle" | "loading" | "done" | "already">("idle");

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!email || state === "loading" || state === "done") return;
    setState("loading");
    try {
      const res = await submitWaitlist(email, source);
      setState(res.already ? "already" : "done");
    } catch {
      setState("idle");
    }
  }

  if (state === "done") {
    return (
      <p className="text-[13px] text-accent">
        You&apos;re on the list. We&apos;ll reach out when Pro launches.
      </p>
    );
  }
  if (state === "already") {
    return (
      <p className="text-[13px] text-text-secondary">
        Already signed up — we&apos;ll let you know.
      </p>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="flex w-full max-w-sm gap-2">
      <input
        type="email"
        required
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder={placeholder}
        className="flex-1 rounded-lg border border-border-c bg-surface-top px-3 py-2 text-[13px] text-text-primary placeholder:text-text-secondary/40 outline-none focus:border-accent/50 transition-colors"
      />
      <button
        type="submit"
        disabled={state === "loading"}
        className="shrink-0 rounded-lg border border-accent/40 bg-accent/10 px-4 py-2 text-[13px] font-medium text-accent transition-colors hover:bg-accent/20 disabled:opacity-50"
      >
        {state === "loading" ? "..." : "Notify me"}
      </button>
    </form>
  );
}

export function Waitlist() {
  return (
    <Section id="waitlist" num="08" title="Stay in the loop">
      <div className="flex flex-col items-center text-center">
        <p className="max-w-[480px] text-[14px] leading-relaxed text-text-secondary">
          NotchDeck v1 is free. When Pro launches — with themes, session history,
          and future agents — you&apos;ll hear it first.{" "}
          <span className="text-text-primary">No spam. One email.</span>
        </p>

        <div className="mt-6">
          <EmailForm source="waitlist-section" />
        </div>

        <p className="mt-4 text-[12px] text-text-secondary/50">
          Or get Pro free now — post NotchDeck on X with 100+ likes and DM{" "}
          <a
            href="https://x.com/navjotdhanawat"
            target="_blank"
            rel="noopener noreferrer"
            className="text-text-secondary underline underline-offset-2 hover:text-text-primary transition-colors"
          >
            @navjotdhanawat
          </a>
        </p>
      </div>
    </Section>
  );
}

// Compact inline form for footer use
export function WaitlistInline() {
  return (
    <div className="flex flex-col gap-2">
      <p className="text-[12px] font-medium text-text-secondary">Get notified at Pro launch</p>
      <EmailForm source="footer" placeholder="your@email.com" />
    </div>
  );
}
