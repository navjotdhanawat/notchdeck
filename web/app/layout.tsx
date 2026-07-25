import type { Metadata } from "next";
import { Instrument_Serif, JetBrains_Mono } from "next/font/google";
import { ThemeProvider } from "@/lib/theme-context";
import { ThemeScript } from "@/lib/theme-script";
import "./globals.css";

const serif = Instrument_Serif({ subsets: ["latin"], weight: "400", style: ["normal","italic"], variable: "--font-serif", display: "swap" });
const mono = JetBrains_Mono({ subsets: ["latin"], variable: "--font-mono", display: "swap" });

export const metadata: Metadata = {
  title: "ClaudeNotch — a live monitor for your Claude Code sessions",
  description: "Turn your MacBook notch into mission control for parallel Claude Code & Codex sessions: glance, jump to the exact pane, and decide in place. 10 themes.",
  openGraph: {
    type: "website",
    title: "ClaudeNotch — a live monitor for your Claude Code sessions",
    description: "Turn your MacBook notch into mission control for parallel Claude Code & Codex sessions: glance, jump to the exact pane, and decide in place. 10 themes.",
  },
  twitter: {
    card: "summary_large_image",
    title: "ClaudeNotch — a live monitor for your Claude Code sessions",
    description: "Turn your MacBook notch into mission control for parallel Claude Code & Codex sessions: glance, jump to the exact pane, and decide in place. 10 themes.",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${serif.variable} ${mono.variable}`} suppressHydrationWarning>
      <head>
        <ThemeScript />
      </head>
      <body><ThemeProvider>{children}</ThemeProvider></body>
    </html>
  );
}
