// Footer: local-only ethos, DynamicNotchKit credit, honesty note. Compact, tasteful.

export function Footer() {
  return (
    <footer className="w-full border-t border-white/[0.04] bg-surface-bottom/50 py-12">
      <div className="mx-auto max-w-[1120px] px-6 text-[13px] leading-relaxed text-text-secondary">
        <p>
          <strong className="font-semibold text-text-primary">
            Local-only.
          </strong>{" "}
          No cloud, no telemetry, no yabai. Your sessions stay on your machine.
        </p>

        <p className="mt-4">
          Built on{" "}
          <a
            href="https://github.com/MrKai77/DynamicNotchKit"
            target="_blank"
            rel="noopener noreferrer"
            className="text-accent underline decoration-accent/40 underline-offset-2 transition-colors hover:decoration-accent"
          >
            DynamicNotchKit
          </a>{" "}
          by MrKai77. Thank you for the foundation.
        </p>

        <p className="mt-4">
          <strong className="font-semibold text-text-primary">
            Honesty note:
          </strong>{" "}
          The Download button is a placeholder. Binaries will be published when
          this landing page ships.
        </p>
      </div>
    </footer>
  );
}
