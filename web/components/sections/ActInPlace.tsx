"use client";

import { useState } from "react";
import { Section } from "@/components/ui/Section";
import { ActCard } from "@/components/stage/ActCard";
import { ACT_FIXTURES, type ActKind, type Session } from "@/lib/types";

/**
 * Friendly labels for the raw choice tokens ActCard emits, so the resolved chip
 * reads "Allowed for session" rather than "allow-session". Ask choices are the
 * chosen option text (e.g. "Production") and aren't tokens, so they fall through
 * the lookup and render as-is.
 */
const RESOLVE_LABELS: Record<string, string> = {
  allow: "Allowed",
  deny: "Denied",
  "allow-session": "Allowed for session",
  approve: "Plan approved",
  "request-changes": "Changes requested",
};
const resolveLabel = (choice: string) => RESOLVE_LABELS[choice] ?? choice;

/**
 * Interactive demo of the three act-in-place decision surfaces: permission,
 * ask, and plan. Each card resolves on click and offers a RESET to replay.
 * Local state per card; independent of the hero engine.
 */
export function ActInPlace() {
  // Each card maintains its own resolved state
  const [resolvedPermission, setResolvedPermission] = useState<string | null>(null);
  const [resolvedAsk, setResolvedAsk] = useState<string | null>(null);
  const [resolvedPlan, setResolvedPlan] = useState<string | null>(null);

  // Fixture sessions for each card (using different agents/terminals for variety)
  const permissionSession: Session = {
    id: "demo-perm",
    title: "fix auth bug",
    agent: "claude",
    terminal: "iTerm2",
    state: "needsPermission",
    activity: "Needs permission · Edit middleware.ts",
    elapsedMin: 27,
  };

  const askSession: Session = {
    id: "demo-ask",
    title: "deploy backend",
    agent: "codex",
    terminal: "WezTerm",
    state: "needsInput",
    activity: "Needs input · deployment target",
    elapsedMin: 15,
  };

  const planSession: Session = {
    id: "demo-plan",
    title: "refactor auth",
    agent: "claude",
    terminal: "Kitty",
    state: "needsInput",
    activity: "Plan ready · 6 steps",
    elapsedMin: 42,
  };

  const cards: Array<{
    kind: ActKind;
    label: string;
    session: Session;
    resolved: string | null;
    onResolve: (choice: string) => void;
    onReset: () => void;
  }> = [
    {
      kind: "permission",
      label: "Permission",
      session: permissionSession,
      resolved: resolvedPermission,
      onResolve: setResolvedPermission,
      onReset: () => setResolvedPermission(null),
    },
    {
      kind: "ask",
      label: "Ask",
      session: askSession,
      resolved: resolvedAsk,
      onResolve: setResolvedAsk,
      onReset: () => setResolvedAsk(null),
    },
    {
      kind: "plan",
      label: "Plan",
      session: planSession,
      resolved: resolvedPlan,
      onResolve: setResolvedPlan,
      onReset: () => setResolvedPlan(null),
    },
  ];

  return (
    <Section
      id="act"
      num="02"
      title="Act in place"
    >
      <div className="grid gap-6 md:grid-cols-3">
        {cards.map(({ kind, label, session, resolved, onResolve, onReset }) => (
          <div key={kind} className="flex flex-col gap-4">
            {/* Card label */}
            <h3 className="font-mono text-xs font-semibold uppercase tracking-wider text-text-secondary/80">
              {label}
            </h3>

            {/* Card container (macOS panel aesthetic) — flex-1 ensures all 3 cards stretch to identical height */}
            <div className="relative flex flex-1 flex-col justify-between overflow-hidden rounded-[26px] border border-border-c bg-surface-bottom p-4 shadow-xl">
              {resolved ? (
                // Resolved state: show choice + reset button
                <div className="flex min-h-[280px] flex-col items-center justify-center gap-4 text-center">
                  <div className="rounded-full border border-accent/25 bg-accent/10 px-4 py-2 font-mono text-sm text-accent">
                    ✓ {resolveLabel(resolved)}
                  </div>
                  <button
                    type="button"
                    onClick={onReset}
                    className="rounded-lg border border-border-c bg-white/[0.08] px-4 py-2 font-mono text-xs font-medium text-text-primary transition hover:bg-white/[0.12] focus:outline-none focus-visible:ring-2 focus-visible:ring-accent/70"
                  >
                    Reset
                  </button>
                </div>
              ) : (
                // Active state: show the ActCard
                <ActCard
                  prompt={ACT_FIXTURES[kind]}
                  session={session}
                  onResolve={onResolve}
                />
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Honesty disclaimer - visible on all viewports */}
      <p className="mt-6 text-center font-mono text-xs text-text-secondary">
        Option numbers are a visual index, not keyboard shortcuts.
      </p>
    </Section>
  );
}
