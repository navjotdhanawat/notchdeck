"use client";

import { useState } from "react";
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
import { Analytics } from "@/components/Analytics";
import { DownloadModal } from "@/components/DownloadModal";

export default function Home() {
  const [showDownloadModal, setShowDownloadModal] = useState(false);

  const openDownloadModal = () => setShowDownloadModal(true);

  return (
    <>
      <Analytics />
      <Nav onDownloadClick={openDownloadModal} />
      <main>
        <Hero onDownloadClick={openDownloadModal} />
        <HowItWorks />
        <ActInPlace />
        <Capabilities />
        <AgentsTerminals />
        <ThemesGallery />
        <Roadmap />
        <Support onDownloadClick={openDownloadModal} />
        <Waitlist />
        <CTA onDownloadClick={openDownloadModal} />
      </main>
      <Footer />

      {showDownloadModal && (
        <DownloadModal onClose={() => setShowDownloadModal(false)} />
      )}
    </>
  );
}
