"use client";
import { useEffect, useRef, useState } from "react";
import { useTheme } from "@/lib/theme-context";
import { THEME_ORDER, PALETTES, type ThemeId } from "@/lib/themes";
import { trackThemeChange } from "@/lib/analytics";

/** macOS system stack for the menu-bar control. */
const SYS =
  "-apple-system,BlinkMacSystemFont,'SF Pro Text','Helvetica Neue',Arial,sans-serif";

/**
 * Menu-bar theme switcher: a button showing the active theme + a dropdown of
 * all 10 themes (each with a swatch + name). Selecting calls setTheme (live
 * recolor + persist). Closes on outside-click/Escape; keyboard navigable.
 */
export function ThemeSwitcher() {
  const { themeId, setTheme, pixelArtEnabled, setPixelArtEnabled, animationTheme, setAnimationTheme } = useTheme();
  const [open, setOpen] = useState(false);
  const [focusedIndex, setFocusedIndex] = useState(-1);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);

  const handleSelectTheme = (id: ThemeId) => {
    setTheme(id);
    trackThemeChange(id, "switcher");
  };

  // Close on outside click
  useEffect(() => {
    if (!open) return;
    const handler = (e: MouseEvent) => {
      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(e.target as Node) &&
        triggerRef.current &&
        !triggerRef.current.contains(e.target as Node)
      ) {
        setOpen(false);
        setFocusedIndex(-1);
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, [open]);

  // Close on Escape, arrow/enter navigation
  useEffect(() => {
    if (!open) return;
    const handler = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        setOpen(false);
        setFocusedIndex(-1);
        triggerRef.current?.focus();
        return;
      }
      if (e.key === "ArrowDown") {
        e.preventDefault();
        setFocusedIndex((prev) => (prev + 1) % THEME_ORDER.length);
        return;
      }
      if (e.key === "ArrowUp") {
        e.preventDefault();
        setFocusedIndex((prev) => (prev - 1 + THEME_ORDER.length) % THEME_ORDER.length);
        return;
      }
      if (e.key === "Enter" && focusedIndex >= 0) {
        e.preventDefault();
        const id = THEME_ORDER[focusedIndex];
        handleSelectTheme(id);
        setOpen(false);
        setFocusedIndex(-1);
        triggerRef.current?.focus();
        return;
      }
    };
    document.addEventListener("keydown", handler);
    return () => document.removeEventListener("keydown", handler);
  }, [open, focusedIndex, setTheme]);

  // Auto-scroll focused item into view
  useEffect(() => {
    if (focusedIndex >= 0 && dropdownRef.current) {
      const items = dropdownRef.current.querySelectorAll("[role='menuitem']");
      items[focusedIndex]?.scrollIntoView({ block: "nearest" });
    }
  }, [focusedIndex]);

  const activePalette = PALETTES[themeId];

  return (
    <div className="relative" style={{ fontFamily: SYS }}>
      <button
        ref={triggerRef}
        type="button"
        onClick={() => setOpen(!open)}
        aria-haspopup="menu"
        aria-expanded={open}
        className="flex items-center gap-1.5 text-[11.5px] font-normal text-text-primary transition hover:text-text-primary/80 focus:outline-none focus-visible:ring-1 focus-visible:ring-accent/70"
      >
        <span className="flex items-center gap-1">
          <span
            className="h-[9px] w-[9px] rounded-full"
            style={{ backgroundColor: activePalette.accent }}
          />
          <span className="hidden sm:inline">{activePalette.name}</span>
        </span>
        <span aria-hidden className="text-[8px]">
          {open ? "▲" : "▼"}
        </span>
      </button>

      {open && (
        <div
          ref={dropdownRef}
          role="menu"
          className="absolute right-0 top-full mt-1.5 z-50 w-[200px] overflow-auto rounded-md border border-white/12 bg-black/85 py-1 shadow-[0_10px_30px_-10px_rgba(0,0,0,0.8)] backdrop-blur-md"
          style={{ maxHeight: "440px" }}
        >
          <div className="px-3 py-1 text-[10px] font-bold uppercase tracking-wider text-text-secondary select-none">Notch Theme</div>
          {THEME_ORDER.map((id, idx) => {
            const palette = PALETTES[id];
            const active = id === themeId;
            const focused = idx === focusedIndex;
            return (
              <button
                key={id}
                type="button"
                role="menuitem"
                tabIndex={focused ? 0 : -1}
                aria-current={active ? "true" : undefined}
                onClick={() => {
                  handleSelectTheme(id);
                  setOpen(false);
                  setFocusedIndex(-1);
                }}
                onMouseEnter={() => setFocusedIndex(idx)}
                className={`flex w-full items-center gap-2.5 px-3 py-2 text-left text-[12px] transition ${
                  focused || active
                    ? "bg-white/10 text-text-primary"
                    : "text-text-secondary hover:bg-white/5"
                } focus:outline-none`}
              >
                {/* Swatch: surface/accent/done dots */}
                <span className="flex flex-none items-center gap-[3px]">
                  <span
                    className="h-[7px] w-[7px] rounded-full"
                    style={{ backgroundColor: palette.surfaceTop }}
                  />
                  <span
                    className="h-[7px] w-[7px] rounded-full"
                    style={{ backgroundColor: palette.accent }}
                  />
                  <span
                    className="h-[7px] w-[7px] rounded-full"
                    style={{ backgroundColor: palette.done }}
                  />
                </span>

                <span className="flex-1">{palette.name}</span>

                {active && (
                  <span aria-hidden className="flex-none text-accent">
                    ✓
                  </span>
                )}
              </button>
            );
          })}

          <div className="my-1 border-t border-white/12" />

          {/* Toggle for Pixel animations option */}
          <button
            type="button"
            role="menuitem"
            className="flex w-full items-center gap-2.5 px-3 py-2 text-left text-[12px] text-text-primary hover:bg-white/10 transition focus:outline-none"
            onClick={() => setPixelArtEnabled(!pixelArtEnabled)}
          >
            <span className="flex-1 font-medium">Pixel Animations</span>
            <input
              type="checkbox"
              checked={pixelArtEnabled}
              onChange={() => {}}
              className="accent-accent pointer-events-none"
              style={{ width: "12px", height: "12px" }}
            />
          </button>

          {/* List of animation style sprite options */}
          {pixelArtEnabled && (
            <>
              <div className="my-1 border-t border-white/12" />
              <div className="px-3 py-1 text-[10px] font-bold uppercase tracking-wider text-text-secondary select-none">Sprite Theme</div>
              {(["lego", "pacman", "pokemon", "mario", "space"] as const).map((tId) => {
                const name = {
                  lego: "Lego Builder",
                  pacman: "Retro Arcade",
                  pokemon: "Pocket Monsters",
                  mario: "Super Mario",
                  space: "Space Invaders",
                }[tId];
                const isSelected = animationTheme === tId;
                return (
                  <button
                    key={tId}
                    type="button"
                    role="menuitem"
                    className={`flex w-full items-center gap-2.5 px-3 py-1.5 text-left text-[12px] transition ${
                      isSelected ? "bg-white/10 text-text-primary" : "text-text-secondary hover:bg-white/5"
                    } focus:outline-none`}
                    onClick={() => setAnimationTheme(tId)}
                  >
                    <span className="flex-1 pl-1">{name}</span>
                    {isSelected && (
                      <span aria-hidden className="flex-none text-accent text-[11px]">
                        ✓
                      </span>
                    )}
                  </button>
                );
              })}
            </>
          )}
        </div>
      )}
    </div>
  );
}
