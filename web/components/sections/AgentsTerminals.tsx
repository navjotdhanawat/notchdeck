import { Section } from "@/components/ui/Section";
import { Badge } from "@/components/ui/Badge";
import { Chip } from "@/components/ui/Chip";

/**
 * Multi-agent, multi-terminal support section.
 * Shows example session rows + chip groups (agents / terminals) indicating
 * shipping vs. planned support. Legend explains the pluggable seams.
 */
export function AgentsTerminals() {
  return (
    <Section
      id="agents-terminals"
      num="04"
      title="Many agents, many terminals"
      note="The pluggable seams: an AgentAdapter per CLI, a TerminalJumper per app. Add one = implement + register."
    >
      <div className="grid gap-8 lg:grid-cols-[1fr,auto]">
        {/* Left: Example session rows */}
        <div className="flex flex-col gap-3 rounded-xl border border-border-c bg-surface-top p-4">
          {/* Claude session */}
          <div className="flex items-center gap-3 rounded-lg px-2 py-[9px] transition-colors hover:bg-white/[0.06]">
            <span
              aria-hidden
              className="mx-[3px] h-[9px] w-[9px] flex-none rounded-full bg-st-working shadow-[0_0_8px_currentColor]"
              style={{ color: "var(--st-working)" }}
            />
            <div className="min-w-0 flex-1">
              <div className="truncate text-[15px] font-semibold leading-tight text-text-primary">
                fix auth bug
              </div>
              <div className="mt-[3px] truncate text-[12px] font-medium text-st-working">
                Writing middleware.ts…
              </div>
            </div>
            <div className="flex flex-none flex-col items-end gap-[6px]">
              <div className="flex gap-[6px]">
                <Badge kind="claude">Claude</Badge>
                <Badge>iTerm2</Badge>
              </div>
              <span className="font-mono text-[11px] tabular-nums text-text-secondary">
                27m
              </span>
            </div>
          </div>

          {/* Codex session */}
          <div className="flex items-center gap-3 rounded-lg px-2 py-[9px] transition-colors hover:bg-white/[0.06]">
            <span
              aria-hidden
              className="mx-[3px] h-[9px] w-[9px] flex-none rounded-full bg-st-working shadow-[0_0_8px_currentColor]"
              style={{ color: "var(--st-working)" }}
            />
            <div className="min-w-0 flex-1">
              <div className="truncate text-[15px] font-semibold leading-tight text-text-primary">
                backend server
              </div>
              <div className="mt-[3px] truncate text-[12px] font-medium text-st-working">
                Running tests…
              </div>
            </div>
            <div className="flex flex-none flex-col items-end gap-[6px]">
              <div className="flex gap-[6px]">
                <Badge kind="codex">Codex</Badge>
                <Badge>WezTerm</Badge>
              </div>
              <span className="font-mono text-[11px] tabular-nums text-text-secondary">
                1h
              </span>
            </div>
          </div>

          {/* Gemini session */}
          <div className="flex items-center gap-3 rounded-lg px-2 py-[9px] transition-colors hover:bg-white/[0.06]">
            <span
              aria-hidden
              className="mx-[3px] h-[9px] w-[9px] flex-none rounded-full bg-st-done shadow-[0_0_8px_currentColor]"
              style={{ color: "var(--st-done)" }}
            />
            <div className="min-w-0 flex-1">
              <div className="truncate text-[15px] font-semibold leading-tight text-text-primary">
                optimize queries
              </div>
              <div className="mt-[3px] truncate text-[12px] font-medium text-st-done">
                Done — click to jump
              </div>
            </div>
            <div className="flex flex-none flex-col items-end gap-[6px]">
              <div className="flex gap-[6px]">
                <Badge kind="gemini">Gemini</Badge>
                <Badge>Kitty</Badge>
              </div>
              <span className="font-mono text-[11px] tabular-nums text-text-secondary">
                5h
              </span>
            </div>
          </div>
        </div>

        {/* Right: Chip groups + legend */}
        <div className="flex flex-col gap-6">
          {/* Agents */}
          <div>
            <div className="mb-3 font-mono text-[11px] uppercase tracking-[0.15em] text-text-secondary">
              Agents
            </div>
            <div className="flex flex-wrap gap-2">
              <Chip on>Claude Code</Chip>
              <Chip on>Codex</Chip>
              <Chip>Gemini CLI</Chip>
            </div>
          </div>

          {/* Terminals */}
          <div>
            <div className="mb-3 font-mono text-[11px] uppercase tracking-[0.15em] text-text-secondary">
              Terminals (jump-to-pane)
            </div>
            <div className="flex flex-wrap gap-2">
              <Chip on>iTerm2</Chip>
              <Chip on>WezTerm</Chip>
              <Chip on>Kitty</Chip>
              <Chip>Terminal.app</Chip>
              <Chip>Ghostty</Chip>
              <Chip>Warp</Chip>
              <Chip>tmux</Chip>
              <Chip>VS Code</Chip>
            </div>
          </div>

          {/* Legend */}
          <div className="max-w-xs text-[11px] leading-relaxed text-text-secondary">
            <p className="mb-2">
              <span className="font-semibold">●</span> solid = shipping precise-jump
              <br />
              <span className="font-semibold">◌</span> dashed = via the seam / raise-to-front
            </p>
            <p>
              badge tint:{" "}
              <span className="text-ag-claude">Claude</span> ·{" "}
              <span className="text-ag-codex">Codex</span> ·{" "}
              <span className="text-ag-gemini">Gemini</span>
            </p>
          </div>
        </div>
      </div>
    </Section>
  );
}
