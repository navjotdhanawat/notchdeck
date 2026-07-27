"use client";

import { useEffect } from "react";

interface DownloadModalProps {
  onClose: () => void;
}

export function DownloadModal({ onClose }: DownloadModalProps) {
  // Prevent body scroll when modal is open
  useEffect(() => {
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = "unset";
    };
  }, []);

  const triggerDownload = () => {
    window.location.href = "/api/download";
  };

  const handleSponsorClick = () => {
    // 1. Open Buy Me a Coffee in a new tab
    window.open("https://buymeacoffee.com/navjotdhanawat", "_blank", "noopener,noreferrer");
    // 2. Trigger the download immediately in this window
    triggerDownload();
    // 3. Close the modal
    onClose();
  };

  const handleJustDownloadClick = () => {
    // 1. Trigger the download immediately
    triggerDownload();
    // 2. Close the modal
    onClose();
  };

  return (
    <div
      onClick={onClose}
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/80 backdrop-blur-sm p-4 transition-all duration-300"
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className="relative w-full max-w-[460px] transform rounded-2xl border border-white/[0.08] bg-surface-top p-7 shadow-2xl transition-all flex flex-col gap-5"
      >
        {/* Close Button */}
        <button
          onClick={onClose}
          type="button"
          aria-label="Close modal"
          className="absolute top-4 right-4 text-text-secondary hover:text-text-primary transition-colors cursor-pointer"
        >
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none" className="stroke-current">
            <path d="M13.5 4.5L4.5 13.5M4.5 4.5L13.5 13.5" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </button>

        <div>
          <span className="font-mono text-[10px] uppercase tracking-wider text-accent">
            Support Open Source
          </span>
          <h3
            style={{ fontFamily: "var(--font-serif)" }}
            className="mt-1 text-2xl font-normal text-text-primary"
          >
            Support NotchDeck Development
          </h3>
        </div>

        <div className="text-[13.5px] leading-relaxed text-text-secondary flex flex-col gap-3">
          <p>
            NotchDeck is fully local, private, and free to use. However, code-signing the macOS app professionally so it opens on Mac without security bypass warnings costs us Apple Developer program fees ($99/year), plus server hosting and API testing configurations.
          </p>
          <p>
            By sponsoring development, you help keep NotchDeck independent, actively maintained, and completely free of tracking, advertisements, or venture capital incentives.
          </p>
        </div>

        <div className="mt-2 flex flex-col gap-3">
          {/* Primary Action: Sponsor & Download */}
          <button
            onClick={handleSponsorClick}
            type="button"
            className="w-full inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-full bg-accent px-6 py-3 text-[14px] font-medium tracking-tight text-on-accent shadow-[0_12px_34px_-12px_var(--accent)] hover:-translate-y-px hover:brightness-105 active:translate-y-0 transition-[transform,filter] duration-200 cursor-pointer"
          >
            Sponsor &amp; Download
          </button>

          {/* Secondary Action: Just Download */}
          <div className="text-center">
            <button
              onClick={handleJustDownloadClick}
              type="button"
              className="text-[12px] text-text-secondary hover:text-text-primary underline underline-offset-2 transition-colors cursor-pointer"
            >
              No thanks, just download NotchDeck
            </button>
          </div>
        </div>

        <p className="text-center text-[10px] text-text-secondary/40">
          Support via one-time or customizable tiers
        </p>
      </div>
    </div>
  );
}
