"use client";
import { motion, useReducedMotion } from "motion/react";

interface SectionProps {
  /** HTML id for nav anchor (e.g. "act", "features"). */
  id?: string;
  /** Section number (displayed in accent color). */
  num: string;
  /** Serif section title. */
  title: string;
  /** Optional note (displayed at the right end of the header). */
  note?: string;
  children: React.ReactNode;
}

/**
 * Marketing section layout: numbered kicker (accent) + serif title + optional
 * note + children. Implements scroll-reveal animation (fade+rise once) gated by
 * reduced-motion preference.
 */
export function Section({ id, num, title, note, children }: SectionProps) {
  const shouldReduceMotion = useReducedMotion();

  return (
    <motion.section
      id={id}
      className="py-16 md:py-20"
      initial={shouldReduceMotion ? {} : { opacity: 0, y: 24 }}
      whileInView={shouldReduceMotion ? {} : { opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "-100px" }}
      transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
    >
      <div className="mx-auto max-w-7xl px-6 md:px-8">
        {/* Section header */}
        <div className="mb-10 flex items-baseline gap-4 md:gap-6">
          <span className="font-mono text-[11px] uppercase tracking-[0.2em] text-accent">
            {num}
          </span>
          <h2 className="font-serif text-3xl font-normal leading-none md:text-4xl">
            {title}
          </h2>
          {note && (
            <span className="ml-auto hidden max-w-sm text-right font-mono text-[11px] leading-relaxed text-text-secondary/60 md:block">
              {note}
            </span>
          )}
        </div>

        {/* Section content */}
        {children}
      </div>
    </motion.section>
  );
}
