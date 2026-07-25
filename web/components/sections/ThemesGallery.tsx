"use client";
import { Section } from "@/components/ui/Section";
import { useTheme } from "@/lib/theme-context";
import { THEME_ORDER, PALETTES } from "@/lib/themes";

/**
 * Live theme gallery — 10 clickable mini-notch preview cards, each rendered in
 * its own theme palette (inline styles). Clicking a card calls `setTheme()` to
 * recolor the whole page AND keeps the menu-bar ThemeSwitcher in sync (both use
 * `useTheme()`). Active theme gets a ring + aria-pressed.
 */
export function ThemesGallery() {
  const { themeId: activeId, setTheme } = useTheme();

  return (
    <Section id="themes" num="05" title="10 switchable themes" note="Click any card to recolor the whole page in real time. Syncs with the menu-bar switcher.">
      <div className="grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-5">
        {THEME_ORDER.map((id) => {
          const p = PALETTES[id];
          const isActive = activeId === id;

          return (
            <button
              key={id}
              type="button"
              onClick={() => setTheme(id)}
              aria-pressed={isActive}
              className={[
                "group relative flex flex-col gap-3 rounded-xl border-2 p-4 transition-all",
                "hover:scale-[1.02] focus:outline-none focus-visible:ring-2 focus-visible:ring-accent/70",
                isActive
                  ? "border-accent ring-2 ring-accent/30"
                  : "border-border-c hover:border-border-c/70",
              ].join(" ")}
            >
              {/* Mini-notch preview — each card uses its own theme palette via inline styles */}
              <div
                className="relative aspect-[2/1] w-full overflow-hidden rounded-lg"
                style={{
                  background: `linear-gradient(to bottom, ${p.surfaceTop}, ${p.surfaceBottom})`,
                  border: `1px solid ${p.border}`,
                }}
              >
                {/* Mini pill indicator */}
                <div
                  className="absolute left-1/2 top-[6px] flex -translate-x-1/2 gap-[3px] rounded-full px-[5px] py-[2px]"
                  style={{
                    backgroundColor: p.innerBox,
                    border: `1px solid ${p.border}`,
                  }}
                >
                  <span
                    className="h-[5px] w-[5px] rounded-full"
                    style={{ backgroundColor: p.working, boxShadow: `0 0 4px ${p.working}` }}
                  />
                  <span
                    className="h-[5px] w-[5px] rounded-full"
                    style={{ backgroundColor: p.done, boxShadow: `0 0 4px ${p.done}` }}
                  />
                </div>

                {/* Mini session rows */}
                <div className="absolute inset-0 flex flex-col justify-center gap-[2px] px-[6px] pt-[16px]">
                  <div className="flex items-center gap-[3px] rounded px-[3px] py-[2px]">
                    <span
                      className="h-[3px] w-[3px] flex-none rounded-full"
                      style={{ backgroundColor: p.working }}
                    />
                    <div className="min-w-0 flex-1">
                      <div
                        className="truncate font-mono text-[5px] font-semibold"
                        style={{ color: p.textPrimary }}
                      >
                        fix auth bug
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center gap-[3px] rounded px-[3px] py-[2px]">
                    <span
                      className="h-[3px] w-[3px] flex-none rounded-full"
                      style={{ backgroundColor: p.done }}
                    />
                    <div className="min-w-0 flex-1">
                      <div
                        className="truncate font-mono text-[5px] font-semibold"
                        style={{ color: p.textPrimary }}
                      >
                        optimize queries
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Theme name */}
              <div className="text-center font-mono text-[11px] font-semibold uppercase tracking-[0.1em] text-text-primary">
                {p.name}
              </div>

              {/* Active indicator */}
              {isActive && (
                <div className="absolute -right-1 -top-1 flex h-5 w-5 items-center justify-center rounded-full bg-accent text-[10px] font-bold text-on-accent">
                  ✓
                </div>
              )}
            </button>
          );
        })}
      </div>
    </Section>
  );
}
