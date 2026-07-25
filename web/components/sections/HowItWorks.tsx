import { Section } from "@/components/ui/Section";

/**
 * 3-step strip explaining how ClaudeNotch works: hooks → notch-bridge → notch/jump.
 * Tagline: "No yabai. No cloud. No telemetry."
 */
export function HowItWorks() {
  const steps = [
    {
      num: "1",
      title: "Hooks capture events",
      desc: "Claude Code hooks fire on session start, state change, and completion.",
    },
    {
      num: "2",
      title: "Bridge forwards to localhost",
      desc: "Bundled notch-bridge sends each event + ITERM_SESSION_ID to a local server.",
    },
    {
      num: "3",
      title: "Notch shows state, click jumps",
      desc: "The notch displays live status; clicking a session jumps to the exact pane.",
    },
  ];

  return (
    <Section id="how" num="01" title="How it works">
      <div className="grid gap-8 md:grid-cols-3">
        {steps.map((step) => (
          <div key={step.num} className="flex flex-col gap-3">
            <div className="flex items-center gap-3">
              <span
                aria-hidden
                className="flex h-10 w-10 flex-none items-center justify-center rounded-full border border-accent/25 bg-accent/10 font-mono text-sm font-semibold text-accent"
              >
                {step.num}
              </span>
              <h3 className="font-mono text-sm font-semibold text-text-primary">
                {step.title}
              </h3>
            </div>
            <p className="pl-13 text-sm leading-relaxed text-text-secondary">{step.desc}</p>
          </div>
        ))}
      </div>

      {/* Tagline */}
      <div className="mt-10 flex items-center justify-center gap-4 rounded-2xl border border-border-c bg-surface-top/50 px-6 py-5 text-center">
        <span className="font-mono text-xs uppercase tracking-wider text-text-secondary">
          No yabai. No cloud. No telemetry.
        </span>
      </div>
    </Section>
  );
}
