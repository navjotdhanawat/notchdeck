"use client";
import { createContext, useContext, useCallback, useSyncExternalStore, useState, useEffect } from "react";
import { PALETTES, paletteVars, type ThemeId, type Palette } from "@/lib/themes";
import type { AnimationThemeId } from "@/lib/types";

const KEY = "claudenotch.theme";

type Ctx = {
  themeId: ThemeId;
  palette: Palette;
  setTheme: (id: ThemeId) => void;
  pixelArtEnabled: boolean;
  setPixelArtEnabled: (enabled: boolean) => void;
  animationTheme: AnimationThemeId;
  setAnimationTheme: (theme: AnimationThemeId) => void;
};

const ThemeCtx = createContext<Ctx | null>(null);

function applyVars(id: ThemeId) {
  const vars = paletteVars(PALETTES[id]);
  const root = document.documentElement;
  for (const k in vars) root.style.setProperty(k, vars[k]);
  root.dataset.theme = id;
}

const listeners = new Set<() => void>();
function subscribe(cb: () => void) {
  listeners.add(cb);
  return () => listeners.delete(cb);
}
function getSnapshot(): ThemeId {
  const id = document.documentElement.dataset.theme as ThemeId | undefined;
  return id && PALETTES[id] ? id : "graphite";
}
function getServerSnapshot(): ThemeId {
  return "graphite";
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const themeId = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);

  const [pixelArtEnabled, setPixelArtEnabledState] = useState(true);
  const [animationTheme, setAnimationThemeState] = useState<AnimationThemeId>("lego");

  // Load from localStorage on client-mount to avoid server snapshot mismatch
  useEffect(() => {
    try {
      const savedArt = localStorage.getItem("claudenotch.pixelArtEnabled");
      if (savedArt !== null) {
        setPixelArtEnabledState(savedArt === "true");
      }
      const savedAnim = localStorage.getItem("claudenotch.animationTheme");
      if (savedAnim !== null && ["lego", "pacman", "pokemon", "mario", "space"].includes(savedAnim)) {
        setAnimationThemeState(savedAnim as AnimationThemeId);
      }
    } catch {}
  }, []);

  const setTheme = useCallback((id: ThemeId) => {
    applyVars(id);
    try { localStorage.setItem(KEY, id); } catch {}
    listeners.forEach((cb) => cb());
  }, []);

  const setPixelArtEnabled = useCallback((enabled: boolean) => {
    setPixelArtEnabledState(enabled);
    try { localStorage.setItem("claudenotch.pixelArtEnabled", String(enabled)); } catch {}
  }, []);

  const setAnimationTheme = useCallback((theme: AnimationThemeId) => {
    setAnimationThemeState(theme);
    try { localStorage.setItem("claudenotch.animationTheme", theme); } catch {}
  }, []);

  return (
    <ThemeCtx.Provider
      value={{
        themeId,
        palette: PALETTES[themeId],
        setTheme,
        pixelArtEnabled,
        setPixelArtEnabled,
        animationTheme,
        setAnimationTheme,
      }}
    >
      {children}
    </ThemeCtx.Provider>
  );
}

export function useTheme() {
  const c = useContext(ThemeCtx);
  if (!c) throw new Error("useTheme must be used within ThemeProvider");
  return c;
}
