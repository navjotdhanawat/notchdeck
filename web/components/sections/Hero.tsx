"use client";
// The hero: masthead (kicker + serif wordmark + subhead + CTAs) sitting above
// the interactive Stage. Copy is confident present tense and accurate to spec §8
// (Claude + Codex ship today, Gemini is planned; usage is tokens + cost only).

import { Button } from "@/components/ui/Button";
import { Stage } from "@/components/stage/Stage";

export function Hero() {
  return (
    <section className="mx-auto w-full max-w-[1120px] px-6 pb-24 pt-20 sm:pt-28">
      {/* masthead */}
      <div className="flex items-center gap-3 text-[11px] font-medium uppercase tracking-[0.42em] text-accent">
        <span aria-hidden className="h-px w-8 bg-accent" />
        Act in place, in your notch
      </div>

      <h1
        style={{ fontFamily: "var(--font-serif)" }}
        className="mt-4 text-[clamp(52px,9vw,104px)] font-normal leading-[0.92] tracking-[-0.01em] text-text-primary"
      >
        Claude<em className="text-accent not-italic">Notch</em>
      </h1>

      <p className="mt-6 max-w-[640px] text-[15px] leading-relaxed text-text-secondary">
        Your MacBook notch becomes mission control for parallel Claude Code and
        Codex sessions. Glance at every run, jump straight to the exact terminal
        pane, and decide right there in the notch — approve a tool, answer a
        question, sign off a plan. <span className="text-text-primary">Gemini is on the way.</span>
      </p>

      {/* CTAs */}
      <div className="mt-8 flex flex-wrap items-center gap-3">
        <Button variant="primary" href="#download">
          Download for macOS
        </Button>
        <Button variant="ghost" href="#act">
          See it in action
        </Button>
      </div>

      {/* tap-to-interject hint */}
      <p className="mt-9 flex items-center gap-2 text-[12.5px] text-text-secondary">
        <span
          aria-hidden
          className="inline-block h-[7px] w-[7px] flex-none rounded-full bg-st-done"
          style={{ boxShadow: "0 0 8px currentColor" }}
        />
        This demo is playing itself — tap the stage to take over, then hit{" "}
        <span className="text-text-primary">Resume demo</span> anytime.
      </p>

      {/* the playground */}
      <div className="mt-5">
        <Stage />
      </div>
    </section>
  );
}
