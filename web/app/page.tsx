"use client";

import { useState } from "react";
import { trackOpenDownloadModal } from "@/lib/analytics";
import { Nav } from "@/components/sections/Nav";
import { Hero } from "@/components/sections/Hero";
import { HowItWorks } from "@/components/sections/HowItWorks";
import { ActInPlace } from "@/components/sections/ActInPlace";
import { Capabilities } from "@/components/sections/Capabilities";
import { AgentsTerminals } from "@/components/sections/AgentsTerminals";
import { ThemesGallery } from "@/components/sections/ThemesGallery";
import { Roadmap } from "@/components/sections/Roadmap";
import { Support } from "@/components/sections/Support";
import { Waitlist } from "@/components/sections/Waitlist";
import { CTA } from "@/components/sections/CTA";
import { Footer } from "@/components/sections/Footer";
import { DownloadModal } from "@/components/DownloadModal";

export default function Home() {
  const [showDownloadModal, setShowDownloadModal] = useState(false);

  const openDownloadModal = (source: string = "unknown") => {
    trackOpenDownloadModal(source);
    setShowDownloadModal(true);
  };

  return (
    <>
      <Nav onDownloadClick={() => openDownloadModal("nav")} />
      <main>
        <Hero onDownloadClick={() => openDownloadModal("hero")} />
        <HowItWorks />
        <ActInPlace />
        <Capabilities />
        <AgentsTerminals />
        <ThemesGallery />
        <Roadmap />
        <Support onDownloadClick={() => openDownloadModal("support")} />
        <Waitlist />
        <CTA onDownloadClick={() => openDownloadModal("cta")} />
      </main>
      <Footer />

      {showDownloadModal && (
        <DownloadModal onClose={() => setShowDownloadModal(false)} />
      )}
    </>
  );
}
