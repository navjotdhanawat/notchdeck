"use client";
import { createContext, useContext, useCallback, useSyncExternalStore } from "react";
import { PALETTES, paletteVars, type ThemeId, type Palette } from "@/lib/themes";

const KEY = "claudenotch.theme";
type Ctx = { themeId: ThemeId; palette: Palette; setTheme: (id: ThemeId) => void };
const ThemeCtx = createContext<Ctx | null>(null);

function applyVars(id: ThemeId) {
  const vars = paletteVars(PALETTES[id]);
  const root = document.documentElement;
  for (const k in vars) root.style.setProperty(k, vars[k]);
  root.dataset.theme = id;
}

// --- external store: <html data-theme> is the source of truth -----------------
// The pre-paint <ThemeScript> commits the saved theme to <html> before first
// paint. We read it through useSyncExternalStore so that:
//   • getServerSnapshot + the hydration render both return "graphite", matching
//     the server HTML → no hydration mismatch in theme-dependent nodes;
//   • right after hydration React adopts the real (already-painted) theme → no
//     flash; and
//   • nothing here touches localStorage during SSR/module eval → no Node
//     `localStorage` ExperimentalWarning.
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

  const setTheme = useCallback((id: ThemeId) => {
    applyVars(id); // writes <html data-theme> + CSS vars — the store's source of truth
    try { localStorage.setItem(KEY, id); } catch {}
    listeners.forEach((cb) => cb()); // notify → getSnapshot re-reads → re-render
  }, []);

  return <ThemeCtx.Provider value={{ themeId, palette: PALETTES[themeId], setTheme }}>{children}</ThemeCtx.Provider>;
}

export function useTheme() {
  const c = useContext(ThemeCtx);
  if (!c) throw new Error("useTheme must be used within ThemeProvider");
  return c;
}
