import type { Metadata, Viewport } from "next";
import { Instrument_Serif, JetBrains_Mono } from "next/font/google";
import { Analytics } from "@vercel/analytics/react";
import { ThemeProvider } from "@/lib/theme-context";
import { ThemeScript } from "@/lib/theme-script";
import "./globals.css";

const serif = Instrument_Serif({ subsets: ["latin"], weight: "400", style: ["normal","italic"], variable: "--font-serif", display: "swap" });
const mono = JetBrains_Mono({ subsets: ["latin"], variable: "--font-mono", display: "swap" });

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? "https://notchdeck.app";
const TITLE = "NotchDeck — AI Agent Monitor for MacBook Notch";
const DESCRIPTION =
  "Turn your MacBook notch into mission control for parallel Claude Code & Codex sessions. Monitor AI coding agents, jump to any terminal pane instantly, approve permissions in place. Free & open source.";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: TITLE,
    template: "%s | NotchDeck",
  },
  description: DESCRIPTION,
  keywords: [
    // Direct product
    "NotchDeck",
    "macOS notch app",
    "MacBook notch monitor",
    // AI agent monitoring — core use case
    "Claude Code monitor",
    "Claude Code session tracker",
    "Codex CLI monitor",
    "AI coding agent dashboard",
    "AI agent session manager",
    // Competitor / adjacent terms
    "claude code status bar",
    "terminal session dashboard",
    "AI pair programmer monitor",
    "parallel coding agents",
    "multi-agent coding monitor",
    // Platform
    "macOS menu bar app",
    "MacBook Pro notch widget",
    "native macOS Swift app",
  ],
  authors: [{ name: "Navjot Dhanawat", url: "https://github.com/navjotdhanawat" }],
  creator: "Navjot Dhanawat",
  publisher: "NotchDeck",
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true, "max-snippet": -1, "max-image-preview": "large", "max-video-preview": -1 },
  },
  alternates: {
    canonical: "./",
  },
  openGraph: {
    type: "website",
    locale: "en_US",
    url: SITE_URL,
    siteName: "NotchDeck",
    title: TITLE,
    description: DESCRIPTION,
    images: [
      {
        url: "/og-image.png?v=2",
        width: 1200,
        height: 630,
        alt: "NotchDeck — AI Agent Monitor for MacBook Notch",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    site: "@navjotdhanawat",
    creator: "@navjotdhanawat",
    title: TITLE,
    description: DESCRIPTION,
    images: ["/og-image.png?v=2"],
  },
  icons: {
    icon: [
      { url: "/favicon.ico?v=2", sizes: "any" },
      { url: "/icon.png?v=2", type: "image/png", sizes: "512x512" },
    ],
    apple: [
      { url: "/apple-touch-icon.png?v=2", sizes: "180x180" },
      { url: "/apple-icon.png?v=2", sizes: "180x180" },
    ],
    shortcut: "/favicon.ico?v=2",
  },
  manifest: "/site.webmanifest",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#000000",
};

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "NotchDeck",
  applicationCategory: "DeveloperApplication",
  operatingSystem: "macOS 14+",
  url: SITE_URL,
  description: DESCRIPTION,
  offers: {
    "@type": "Offer",
    price: "0",
    priceCurrency: "USD",
  },
  author: {
    "@type": "Person",
    name: "Navjot Dhanawat",
    url: "https://github.com/navjotdhanawat",
  },
  softwareVersion: "1.0",
  downloadUrl: `${SITE_URL}/api/download`,
  license: "https://opensource.org/licenses/MIT",
  featureList: [
    "Monitor Claude Code sessions in MacBook notch",
    "Monitor Codex CLI sessions",
    "Click to jump to terminal pane",
    "Approve permissions in place",
    "Cost and token tracking",
    "10 built-in themes",
    "Fully local, no telemetry",
  ],
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${serif.variable} ${mono.variable}`} suppressHydrationWarning>
      <head>
        <ThemeScript />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      </head>
      <body>
        <ThemeProvider>{children}</ThemeProvider>
        <Analytics />
      </body>
    </html>
  );
}
