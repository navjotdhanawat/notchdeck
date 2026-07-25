// The final CTA band: a bold headline, primary Download button (placeholder),
// requirements line, and an honesty note. Centered, wide breathing room.

import { Button } from "@/components/ui/Button";

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

        <div className="mt-8">
          <Button
            variant="primary"
            href="#"
            data-download
            className="text-[15px]"
          >
            Download for macOS
          </Button>
        </div>

        <p className="mt-5 max-w-[620px] text-[13px] leading-relaxed text-text-secondary">
          <span className="text-text-primary">
            Apple Silicon · macOS 14+ · iTerm2 / WezTerm / Kitty · Claude Code
          </span>
        </p>

        <p className="mt-4 text-[12px] text-text-secondary">
          The Download button is a placeholder for now — we&apos;ll publish binaries
          when the landing page ships.
        </p>
      </div>
    </section>
  );
}
