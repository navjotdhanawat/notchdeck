import { Nav } from "@/components/sections/Nav";
import { Hero } from "@/components/sections/Hero";
import { HowItWorks } from "@/components/sections/HowItWorks";
import { ActInPlace } from "@/components/sections/ActInPlace";
import { Capabilities } from "@/components/sections/Capabilities";
import { AgentsTerminals } from "@/components/sections/AgentsTerminals";
import { ThemesGallery } from "@/components/sections/ThemesGallery";
import { Roadmap } from "@/components/sections/Roadmap";
import { CTA } from "@/components/sections/CTA";
import { Footer } from "@/components/sections/Footer";

export default function Home() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <HowItWorks />
        <ActInPlace />
        <Capabilities />
        <AgentsTerminals />
        <ThemesGallery />
        <Roadmap />
        <CTA />
      </main>
      <Footer />
    </>
  );
}
