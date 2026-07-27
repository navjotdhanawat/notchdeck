"use client";
import React from "react";
import type { TokenUsage } from "@/lib/types";

function fmtTokens(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}k`;
  return `${n}`;
}

export function PixelGauge({ tokens }: { tokens: TokenUsage }) {
  const total = tokens.total;
  if (total <= 0) return null;

  const segmentsCount = 20;

  // Proportional scaling for bar segments
  const readSegments = Math.round((tokens.cacheRead / total) * segmentsCount);
  const creationSegments = Math.round((tokens.cacheCreation / total) * segmentsCount);
  const outputSegments = Math.round((tokens.output / total) * segmentsCount);
  const inputSegments = Math.max(0, segmentsCount - (readSegments + creationSegments + outputSegments));

  return (
    <div className="mt-2 flex flex-col gap-1.5 align-left">
      {/* 20-segment retro styled health/status gauge */}
      <div className="inline-flex gap-[2px] rounded bg-black/40 p-[3px] w-fit">
        {Array.from({ length: segmentsCount }).map((_, index) => {
          let color = "var(--text-secondary)"; // Default Input (Gray)
          if (index < readSegments) {
            color = "var(--st-working)"; // Cache Read (Blue)
          } else if (index < readSegments + creationSegments) {
            color = "var(--st-perm)"; // Cache Create (Orange)
          } else if (index < readSegments + creationSegments + inputSegments) {
            color = "var(--text-secondary)"; // Input (Gray)
          } else {
            color = "var(--st-done)"; // Output (Green)
          }

          return (
            <div
              key={index}
              className="h-[11px] w-[8px] rounded-[1px] shadow-[0_0_1px_rgba(0,0,0,0.3)]"
              style={{ backgroundColor: color }}
            />
          );
        })}
      </div>

      {/* Legend - 2x2 grid representing categories cleanly */}
      <div className="flex flex-col gap-1 text-[9.5px] font-semibold text-text-secondary select-none">
        <div className="flex gap-[12px]">
          <div className="flex items-center gap-[4px]">
            <span className="h-[5px] w-[5px] rounded-full bg-st-working" />
            <span>Read: {fmtTokens(tokens.cacheRead)}</span>
          </div>
          <div className="flex items-center gap-[4px]">
            <span className="h-[5px] w-[5px] rounded-full bg-st-perm" />
            <span>Create: {fmtTokens(tokens.cacheCreation)}</span>
          </div>
        </div>
        <div className="flex gap-[12px]">
          <div className="flex items-center gap-[4px]">
            <span className="h-[5px] w-[5px] rounded-full bg-text-secondary" />
            <span>Input: {fmtTokens(tokens.input)}</span>
          </div>
          <div className="flex items-center gap-[4px]">
            <span className="h-[5px] w-[5px] rounded-full bg-st-done" />
            <span>Output: {fmtTokens(tokens.output)}</span>
          </div>
        </div>
      </div>
    </div>
  );
}
