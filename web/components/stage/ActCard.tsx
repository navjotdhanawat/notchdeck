"use client";
// The act-in-place card: when a session blocks on a decision, the notch becomes
// the decision surface. Three layouts (permission / ask / plan) selected by
// `prompt.kind`, each wired to `onResolve(choice)` with a string the engine's
// resolveAct() understands. All colors are theme tokens, so switching themes
// recolors the card. Enter/exit run through the parent-owned AnimatePresence via
// a keyed motion root (fade + scale), collapsed to instant under reduced motion.

import { useState, useEffect } from "react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import type { ActKind, ActPrompt, DiffLine, Session, SessionState } from "@/lib/types";
import { Badge } from "@/components/ui/Badge";
import { AnimatedPixelArt } from "@/components/stage/PixelArt";
import { useTheme } from "@/lib/theme-context";

/** Notch/panel body reads as native macOS, not the page serif. */
const SYS =
  "-apple-system,BlinkMacSystemFont,'SF Pro Text','Helvetica Neue',Arial,sans-serif";

const agentLabel = (a: Session["agent"]) => a[0].toUpperCase() + a.slice(1);

/** Session title → a branch/project-style label (mockup shows "fix-auth-bug"). */
const projectLabel = (title: string) =>
  title.trim().toLowerCase().replace(/\s+/g, "-");

/** Per-kind header: label + a glowing status dot, tinted onto the state token. */
const KIND: Record<ActKind, { label: string; tintText: string; dotBg: string }> = {
  permission: { label: "Permission", tintText: "text-st-perm", dotBg: "bg-st-perm" },
  ask: { label: "Claude asks", tintText: "text-st-ask", dotBg: "bg-st-ask" },
  plan: { label: "Plan ready", tintText: "text-st-plan", dotBg: "bg-st-plan" },
};

// --- shared pieces ----------------------------------------------------------

function PanelTop({ kind }: { kind: ActKind }) {
  const { pixelArtEnabled, animationTheme } = useTheme();
  const [mounted, setMounted] = useState(false);
  useEffect(() => {
    setMounted(true);
  }, []);
  const k = KIND[kind];
  const state: SessionState = kind === "ask" ? "needsInput" : "needsPermission";

  return (
    <div className={`flex items-center gap-2 px-[2px] pb-[10px] text-[13px] font-semibold ${k.tintText}`}>
      {mounted && pixelArtEnabled ? (
        <div className="flex-none">
          <AnimatedPixelArt state={state} size={20} theme={animationTheme} />
        </div>
      ) : (
        <span
          aria-hidden
          className={`h-2 w-2 flex-none rounded-full ${k.dotBg}`}
          style={{ boxShadow: "0 0 8px currentColor" }}
        />
      )}
      {k.label}
    </div>
  );
}

/** project · agent · terminal — who is asking. */
function ContextStrip({ session }: { session: Session }) {
  return (
    <div className="flex items-center gap-[7px] px-[2px] pb-[11px] text-[11.5px]">
      <span className="truncate font-medium text-text-secondary">
        {projectLabel(session.title)}
      </span>
      <Badge kind={session.agent}>{agentLabel(session.agent)}</Badge>
      <Badge>{session.terminal}</Badge>
    </div>
  );
}

function GhostButton({
  children,
  onClick,
}: {
  children: React.ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex flex-1 items-center justify-center gap-2 rounded-[11px] border border-border-c bg-white/[0.08] px-3 py-[10px] text-[13px] font-medium text-text-primary transition hover:-translate-y-px hover:bg-white/[0.12] focus:outline-none focus-visible:ring-2 focus-visible:ring-accent/70"
    >
      {children}
    </button>
  );
}

function PrimaryButton({
  children,
  onClick,
}: {
  children: React.ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex flex-1 items-center justify-center gap-2 rounded-[11px] bg-accent px-3 py-[10px] text-[13px] font-semibold text-on-accent transition hover:-translate-y-px hover:brightness-105 focus:outline-none focus-visible:ring-2 focus-visible:ring-accent/70"
    >
      {children}
    </button>
  );
}

// --- permission -------------------------------------------------------------

function DiffRow({ line }: { line: DiffLine }) {
  const isAdd = line.type === "add";
  const isDel = line.type === "del";
  const rowBg = isAdd ? "bg-st-done/10" : isDel ? "bg-st-failed/10" : "";
  const codeColor = isAdd ? "text-st-done" : isDel ? "text-st-failed" : "text-text-secondary";
  // Continuation lines (blank gutter) carry no +/- marker, just alignment.
  const mark = line.lineNo === "" ? "  " : isAdd ? "+ " : isDel ? "- " : "  ";
  return (
    <div className={`flex gap-3 px-3 py-[2.5px] leading-[1.55] ${rowBg}`}>
      <span aria-hidden className="w-4 flex-none select-none text-right text-text-secondary/50">
        {line.lineNo}
      </span>
      <span className={`whitespace-pre ${codeColor}`}>
        {mark}
        {line.text}
      </span>
    </div>
  );
}

function PermissionCard({
  prompt,
  session,
  onResolve,
}: {
  prompt: ActPrompt;
  session: Session;
  onResolve: (choice: string) => void;
}) {
  return (
    <>
      <PanelTop kind="permission" />
      <ContextStrip session={session} />

      <div className="mb-[11px] flex items-center gap-2 px-[2px] text-[13px]">
        <span aria-hidden className="text-st-perm">
          ⚠
        </span>
        <span className="text-text-secondary">{prompt.tool}</span>
        <span className="truncate font-mono text-[12.5px] text-text-primary">
          {prompt.file}
        </span>
      </div>

      <div className="overflow-hidden rounded-[11px] border border-border-c bg-inner-box font-mono text-[12px]">
        {prompt.diff?.map((line, i) => (
          <DiffRow key={i} line={line} />
        ))}
        <div className="flex gap-[10px] border-t border-border-c px-3 py-[6px] text-[11px]">
          <span className="text-st-done">+{prompt.added ?? 0}</span>
          <span className="text-st-failed">−{prompt.removed ?? 0}</span>
        </div>
      </div>

      <div className="mt-[13px] flex gap-[9px]">
        <GhostButton onClick={() => onResolve("deny")}>Deny</GhostButton>
        <PrimaryButton onClick={() => onResolve("allow")}>Allow</PrimaryButton>
      </div>
      <div className="mt-2 flex">
        <GhostButton onClick={() => onResolve("allow-session")}>
          Allow for this session
        </GhostButton>
      </div>
    </>
  );
}

// --- ask --------------------------------------------------------------------

function AskCard({
  prompt,
  session,
  onResolve,
}: {
  prompt: ActPrompt;
  session: Session;
  onResolve: (choice: string) => void;
}) {
  return (
    <>
      <PanelTop kind="ask" />
      <ContextStrip session={session} />

      <div className="mb-[11px] px-[2px] text-[14px] font-medium text-text-primary">
        {prompt.question}
      </div>

      <div className="flex flex-col gap-2">
        {prompt.options?.map((opt, i) => (
          <button
            key={opt}
            type="button"
            onClick={() => onResolve(opt)}
            className="flex w-full items-center gap-[11px] rounded-[10px] border border-st-ask/20 bg-st-ask/10 px-3 py-[10px] text-left text-[13px] text-text-primary transition hover:border-st-ask/40 hover:bg-st-ask/20 focus:outline-none focus-visible:ring-2 focus-visible:ring-accent/70"
          >
            {/* number is a VISUAL INDEX only — not a keyboard shortcut (§8) */}
            <span
              aria-hidden
              className="min-w-[22px] flex-none rounded-md border border-st-ask/25 bg-black/35 py-[3px] text-center font-mono text-[11px] text-st-ask"
            >
              {i + 1}
            </span>
            {opt}
          </button>
        ))}
      </div>
    </>
  );
}

// --- plan -------------------------------------------------------------------

function PlanCard({
  prompt,
  session,
  onResolve,
}: {
  prompt: ActPrompt;
  session: Session;
  onResolve: (choice: string) => void;
}) {
  return (
    <>
      <PanelTop kind="plan" />
      <ContextStrip session={session} />

      <div className="relative flex max-h-[150px] flex-col gap-2 overflow-hidden px-[2px] pb-[4px] pt-[2px]">
        {prompt.steps?.map((step, i) => (
          <div key={i} className="flex gap-[11px] text-[12.5px] text-text-primary/85">
            <span aria-hidden className="w-[14px] flex-none font-mono text-[11px] text-st-plan">
              {i + 1}
            </span>
            {step}
          </div>
        ))}
        {/* fade the clipped tail into the panel surface */}
        <span
          aria-hidden
          className="pointer-events-none absolute inset-x-0 bottom-0 h-[38px]"
          style={{ background: "linear-gradient(to top, var(--surface-bottom), transparent)" }}
        />
      </div>

      {prompt.moreCount ? (
        <div className="px-[2px] pt-1 font-mono text-[11px] text-st-plan/80">
          +{prompt.moreCount} more steps
        </div>
      ) : null}

      <div className="mt-[13px] flex gap-[9px]">
        <GhostButton onClick={() => onResolve("request-changes")}>
          Request changes
        </GhostButton>
        <PrimaryButton onClick={() => onResolve("approve")}>Approve plan</PrimaryButton>
      </div>
    </>
  );
}

// --- root -------------------------------------------------------------------

/**
 * The act-in-place card. Renders inside the `Notch` children slot. Pass
 * `prompt={session.act ?? null}` and keep the component mounted: when the prompt
 * clears (after resolveAct), the card animates out via `AnimatePresence`.
 *
 * `onResolve(choice)` fires with the picked action. Choice strings match the
 * engine's resolveAct():
 *   permission → "deny" | "allow" | "allow-session"
 *   ask        → the chosen option label (e.g. "Production")
 *   plan       → "approve" | "request-changes"
 */
export function ActCard({
  prompt,
  session,
  onResolve,
}: {
  prompt: ActPrompt | null;
  session: Session;
  onResolve: (choice: string) => void;
}) {
  const reduce = useReducedMotion();
  return (
    <AnimatePresence mode="wait">
      {prompt && (
        <motion.div
          key={prompt.kind}
          role="group"
          aria-label={`${KIND[prompt.kind].label} — ${session.title}`}
          style={{ fontFamily: SYS }}
          initial={reduce ? false : { opacity: 0, scale: 0.96 }}
          animate={{ opacity: 1, scale: 1 }}
          exit={{ opacity: 0, scale: reduce ? 1 : 0.96 }}
          transition={{ duration: reduce ? 0 : 0.2, ease: "easeOut" }}
        >
          {prompt.kind === "permission" && (
            <PermissionCard prompt={prompt} session={session} onResolve={onResolve} />
          )}
          {prompt.kind === "ask" && (
            <AskCard prompt={prompt} session={session} onResolve={onResolve} />
          )}
          {prompt.kind === "plan" && (
            <PlanCard prompt={prompt} session={session} onResolve={onResolve} />
          )}
        </motion.div>
      )}
    </AnimatePresence>
  );
}
