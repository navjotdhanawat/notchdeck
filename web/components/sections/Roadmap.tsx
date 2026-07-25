import { Section } from "@/components/ui/Section";
import { Badge } from "@/components/ui/Badge";

/**
 * Roadmap section — three exploratory/future capability cards.
 * All tagged "later" or "exploring" to indicate non-shipping status.
 */
export function Roadmap() {
  return (
    <Section
      id="roadmap"
      num="06"
      title="Beyond the glass"
      note="Same model, further reach. Sketches, not designs — furthest out on the roadmap."
    >
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
        {/* SSH Remote */}
        <div className="flex flex-col gap-4 rounded-xl border border-border-c bg-surface-top p-6">
          <div className="flex items-start justify-between">
            <h3 className="font-mono text-base font-semibold text-text-primary">
              SSH remote
            </h3>
            <span className="rounded-md border border-dashed border-border-c/50 bg-transparent px-[7px] py-[2px] font-mono text-[10px] leading-none text-text-secondary/60">
              later
            </span>
          </div>
          <p className="text-sm leading-relaxed text-text-secondary">
            Monitor sessions running on a remote box; the bridge posts over a tunnel. Jump
            opens the local terminal already SSH&apos;d in.
          </p>
          {/* Example row */}
          <div className="flex items-center gap-3 rounded-lg border border-border-c bg-inner-box px-2 py-[9px]">
            <span
              aria-hidden
              className="mx-[3px] h-[9px] w-[9px] flex-none rounded-full bg-st-working shadow-[0_0_8px_currentColor]"
              style={{ color: "var(--st-working)" }}
            />
            <div className="min-w-0 flex-1">
              <div className="truncate text-[13.5px] font-semibold leading-tight text-text-primary">
                train-model
              </div>
              <div className="mt-[2px] truncate text-[11px] font-medium text-text-secondary">
                epoch 3/10 · loss 0.42
              </div>
            </div>
            <Badge>prod-box ⇢ ssh</Badge>
          </div>
        </div>

        {/* Mobile Relay */}
        <div className="flex flex-col gap-4 rounded-xl border border-border-c bg-surface-top p-6">
          <div className="flex items-start justify-between">
            <h3 className="font-mono text-base font-semibold text-text-primary">
              Mobile relay
            </h3>
            <span className="rounded-md border border-dashed border-border-c/50 bg-transparent px-[7px] py-[2px] font-mono text-[10px] leading-none text-text-secondary/60">
              later
            </span>
          </div>
          <p className="text-sm leading-relaxed text-text-secondary">
            Mirror the notch to your phone (Happy/Omnara pattern) — get the permission prompt
            and approve from anywhere.
          </p>
          {/* Phone mockup */}
          <div className="mx-auto flex h-[120px] w-[60px] items-start justify-center rounded-[12px] border-2 border-border-c bg-gradient-to-b from-surface-top to-surface-bottom p-2">
            <div className="rounded-full border border-border-c bg-inner-box px-2 py-1 font-mono text-[9px] leading-none text-text-primary">
              🟠2 🔵1
            </div>
          </div>
        </div>

        {/* Cost & Limits */}
        <div className="flex flex-col gap-4 rounded-xl border border-border-c bg-surface-top p-6">
          <div className="flex items-start justify-between">
            <h3 className="font-mono text-base font-semibold text-text-primary">
              Cost &amp; limits
            </h3>
            <span className="rounded-md border border-dashed border-border-c/50 bg-transparent px-[7px] py-[2px] font-mono text-[10px] leading-none text-text-secondary/60">
              exploring
            </span>
          </div>
          <p className="text-sm leading-relaxed text-text-secondary">
            The usage header, expanded: burn-down per window, projected reset, and server-truth
            rate limits (CCSeva OAuth), not just local token math.
          </p>
          {/* Usage bar mockup */}
          <div className="flex items-center justify-between gap-3 rounded-lg border border-border-c bg-inner-box px-3 py-2">
            <span className="font-mono text-[11px] font-semibold" style={{ color: "var(--needs-input-dot)" }}>
              ✦ 5h
            </span>
            <div className="relative h-2 w-[90px] flex-none overflow-hidden rounded-full bg-border-c">
              <div
                className="absolute inset-y-0 left-0 rounded-full"
                style={{ width: "11%", backgroundColor: "var(--needs-input-dot)" }}
              />
            </div>
            <span className="font-mono text-[10px] text-text-secondary/70">
              resets 4h01m
            </span>
          </div>
        </div>
      </div>
    </Section>
  );
}
