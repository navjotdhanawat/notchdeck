"use client";

import { useEffect, useState } from "react";

interface DownloadModalProps {
  onClose: () => void;
}

type InstallMethod = "brew" | "curl" | "dmg";

export function DownloadModal({ onClose }: DownloadModalProps) {
  const [activeTab, setActiveTab] = useState<InstallMethod>("brew");
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = "unset";
    };
  }, []);

  const brewCommand = "brew install navjotdhanawat/notchdeck/notchdeck";
  const curlCommand = "curl -fsSL https://notchdeck.app/api/install | bash";

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const triggerDownload = () => {
    window.location.href = "/api/download";
  };

  const handleSponsorClick = () => {
    window.open("https://buymeacoffee.com/navjotdhanawat", "_blank", "noopener,noreferrer");
    triggerDownload();
    onClose();
  };

  return (
    <div
      onClick={onClose}
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/80 backdrop-blur-sm p-4 transition-all duration-300"
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className="relative w-full max-w-[500px] transform rounded-2xl border border-white/[0.08] bg-surface-top p-7 shadow-2xl transition-all flex flex-col gap-5"
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
            Get NotchDeck
          </span>
          <h3
            style={{ fontFamily: "var(--font-serif)" }}
            className="mt-1 text-2xl font-normal text-text-primary"
          >
            Choose Installation Method
          </h3>
        </div>

        {/* Tab Selector */}
        <div className="grid grid-cols-3 gap-1 rounded-xl bg-white/[0.04] p-1 border border-white/[0.06]">
          <button
            type="button"
            onClick={() => setActiveTab("brew")}
            className={`flex items-center justify-center gap-1.5 rounded-lg py-2 text-[13px] font-medium transition-all cursor-pointer ${
              activeTab === "brew"
                ? "bg-white/[0.1] text-text-primary shadow-sm"
                : "text-text-secondary hover:text-text-primary"
            }`}
          >
            <span>🍺</span> Homebrew
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("curl")}
            className={`flex items-center justify-center gap-1.5 rounded-lg py-2 text-[13px] font-medium transition-all cursor-pointer ${
              activeTab === "curl"
                ? "bg-white/[0.1] text-text-primary shadow-sm"
                : "text-text-secondary hover:text-text-primary"
            }`}
          >
            <span>⚡</span> Curl Script
          </button>
          <button
            type="button"
            onClick={() => setActiveTab("dmg")}
            className={`flex items-center justify-center gap-1.5 rounded-lg py-2 text-[13px] font-medium transition-all cursor-pointer ${
              activeTab === "dmg"
                ? "bg-white/[0.1] text-text-primary shadow-sm"
                : "text-text-secondary hover:text-text-primary"
            }`}
          >
            <span>📦</span> DMG Disk Image
          </button>
        </div>

        {/* Tab Content */}
        <div className="flex flex-col gap-4">
          {activeTab === "brew" && (
            <div className="flex flex-col gap-3">
              <p className="text-[13px] text-text-secondary leading-relaxed">
                Install NotchDeck using Homebrew on macOS:
              </p>
              <div className="relative group rounded-xl border border-white/[0.08] bg-black/50 p-3.5 font-mono text-[12.5px] text-text-primary flex items-center justify-between">
                <code className="select-all overflow-x-auto pr-2">{brewCommand}</code>
                <button
                  type="button"
                  onClick={() => copyToClipboard(brewCommand)}
                  className="shrink-0 rounded-md bg-white/[0.08] px-2.5 py-1 text-[11px] font-sans font-medium text-text-primary hover:bg-white/[0.15] transition-colors cursor-pointer"
                >
                  {copied ? "Copied! ✓" : "Copy"}
                </button>
              </div>
              <p className="text-[11px] text-text-secondary/60">
                Alternative: <code className="text-text-secondary">brew tap navjotdhanawat/notchdeck && brew install notchdeck</code>
              </p>
            </div>
          )}

          {activeTab === "curl" && (
            <div className="flex flex-col gap-3">
              <p className="text-[13px] text-text-secondary leading-relaxed">
                Run our automated installer script in Terminal:
              </p>
              <div className="relative group rounded-xl border border-white/[0.08] bg-black/50 p-3.5 font-mono text-[12.5px] text-text-primary flex items-center justify-between">
                <code className="select-all overflow-x-auto pr-2">{curlCommand}</code>
                <button
                  type="button"
                  onClick={() => copyToClipboard(curlCommand)}
                  className="shrink-0 rounded-md bg-white/[0.08] px-2.5 py-1 text-[11px] font-sans font-medium text-text-primary hover:bg-white/[0.15] transition-colors cursor-pointer"
                >
                  {copied ? "Copied! ✓" : "Copy"}
                </button>
              </div>
              <p className="text-[11px] text-text-secondary/60">
                Downloads DMG, mounts image, installs to /Applications, and removes quarantine flag automatically.
              </p>
            </div>
          )}

          {activeTab === "dmg" && (
            <div className="flex flex-col gap-4">
              <p className="text-[13px] text-text-secondary leading-relaxed">
                Download the standalone macOS disk image (`.dmg`), open it, and drag NotchDeck to your Applications folder.
              </p>

              <div className="flex flex-col gap-2.5">
                <button
                  onClick={triggerDownload}
                  type="button"
                  className="w-full inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-full bg-accent px-6 py-3 text-[14px] font-medium tracking-tight text-on-accent shadow-[0_12px_34px_-12px_var(--accent)] hover:-translate-y-px hover:brightness-105 active:translate-y-0 transition-[transform,filter] duration-200 cursor-pointer"
                >
                  Download NotchDeck.dmg (macOS 14+)
                </button>

                <button
                  onClick={handleSponsorClick}
                  type="button"
                  className="w-full inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-full border border-white/[0.1] bg-white/[0.04] px-6 py-2.5 text-[13px] font-medium text-text-primary hover:bg-white/[0.08] transition-colors cursor-pointer"
                >
                  ☕ Sponsor Development &amp; Download
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Footer Note */}
        <div className="border-t border-white/[0.06] pt-4 text-center">
          <p className="text-[11px] text-text-secondary/60">
            Requires macOS 14 Sonoma or later · Apple Silicon Mac
          </p>
        </div>
      </div>
    </div>
  );
}
