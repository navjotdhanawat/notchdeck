import { Nav } from "@/components/sections/Nav";
import { Hero } from "@/components/sections/Hero";
import { HowItWorks } from "@/components/sections/HowItWorks";
import { ActInPlace } from "@/components/sections/ActInPlace";
import { Capabilities } from "@/components/sections/Capabilities";
import { AgentsTerminals } from "@/components/sections/AgentsTerminals";
import { ThemesGallery } from "@/components/sections/ThemesGallery";
import { Roadmap } from "@/components/sections/Roadmap";
import { Pricing } from "@/components/sections/Pricing";
import { Waitlist } from "@/components/sections/Waitlist";
import { CTA } from "@/components/sections/CTA";
import { Footer } from "@/components/sections/Footer";
import { Analytics } from "@/components/Analytics";

export default function Home() {
  return (
    <>
      <Analytics />
      <Nav />
      <main>
        <Hero />
        <HowItWorks />
        <ActInPlace />
        <Capabilities />
        <AgentsTerminals />
        <ThemesGallery />
        <Roadmap />
        <Pricing />
        <Waitlist />
        <CTA />
      </main>
      <Footer />
    </>
  );
}
