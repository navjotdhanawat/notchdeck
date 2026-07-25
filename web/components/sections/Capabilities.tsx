import { Section } from "@/components/ui/Section";

/**
 * Full capability inventory grid (12 capabilities from spec §7.1).
 * Accurate to shipped reality: Gemini = planned; precise-jump for
 * iTerm2/WezTerm/Kitty, raise-to-front for others; usage = tokens + cost only.
 */
export function Capabilities() {
  const capabilities = [
    {
      glyph: "👁️",
      title: "Glanceable multi-session monitor",
      desc: "Track all parallel sessions with 5 live states at a glance.",
    },
    {
      glyph: "🎯",
      title: "Precise click-to-jump",
      desc: "Click any session row to jump directly to the exact pane.",
    },
    {
      glyph: "⚡",
      title: "Act-in-place decisions",
      desc: "Handle permissions, questions, and plan approval right from the notch.",
    },
    {
      glyph: "📊",
      title: "Rich glance rows",
      desc: "Agent/terminal badges, activity, elapsed time per session.",
    },
    {
      glyph: "💰",
      title: "Usage & cost tracking",
      desc: "Live token count and cost display (tokens + $ only).",
    },
    {
      glyph: "🔔",
      title: "Completion sounds",
      desc: "Glass, Basso, or Funk — toggleable audio notifications.",
    },
    {
      glyph: "🎨",
      title: "10 live themes",
      desc: "Switch themes instantly; the whole UI recolors in real time.",
    },
    {
      glyph: "🤖",
      title: "Multi-agent support",
      desc: "Claude ✓ · Codex ✓ · Gemini (planned) via AgentProvider seam.",
    },
    {
      glyph: "💻",
      title: "Multi-terminal jump",
      desc: "iTerm2/WezTerm/Kitty get precise jump; others raise-to-front.",
    },
    {
      glyph: "🔧",
      title: "Self-configuring hooks",
      desc: "Auto-installs with settings backup; zero manual config.",
    },
    {
      glyph: "🔒",
      title: "Private & local-only",
      desc: "No cloud, no telemetry, no yabai. Everything stays on your Mac.",
    },
    {
      glyph: "🔍",
      title: "Hover-expand rows",
      desc: "Hover over session rows for expanded details and context.",
    },
  ];

  return (
    <Section id="features" num="03" title="Everything it does">
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
        {capabilities.map((cap) => (
          <div key={cap.title} className="flex gap-4">
            {/* Glyph */}
            <span
              aria-hidden
              className="flex h-12 w-12 flex-none items-center justify-center rounded-xl border border-border-c bg-surface-top text-2xl"
            >
              {cap.glyph}
            </span>

            {/* Text */}
            <div className="flex flex-col gap-1">
              <h3 className="font-mono text-sm font-semibold text-text-primary">
                {cap.title}
              </h3>
              <p className="text-sm leading-relaxed text-text-secondary">{cap.desc}</p>
            </div>
          </div>
        ))}
      </div>
    </Section>
  );
}
