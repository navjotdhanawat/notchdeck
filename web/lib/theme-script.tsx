import { THEME_ORDER, PALETTES, paletteVars } from "@/lib/themes";

/**
 * Serialized { themeId → CSS-var map } built from the single source of truth
 * (themes.ts). No hex is hand-duplicated here — it is derived from PALETTES.
 */
const THEME_VARS: Record<string, Record<string, string>> = Object.fromEntries(
  THEME_ORDER.map((id) => [id, paletteVars(PALETTES[id])])
);

/**
 * Blocking pre-paint theme script (rendered into <head>). Before React hydrates
 * — and before first paint — it reads the saved theme from localStorage,
 * validates it against the known ids (falling back to "graphite"), then writes
 * both `data-theme` and every CSS custom property onto <html>. This means the
 * very first paint is already the correct theme (no flash), and the DOM the
 * ThemeProvider adopts on mount matches what the user should see.
 *
 * Runs only in the browser, so it never touches localStorage during SSR/module
 * eval (which is what surfaced the Node `localStorage` ExperimentalWarning).
 */
export function ThemeScript() {
  const script =
    `window.__CN_THEME_VARS=${JSON.stringify(THEME_VARS)};` +
    `(function(){try{` +
    `var id=localStorage.getItem('claudenotch.theme');` +
    `if(!window.__CN_THEME_VARS[id])id='graphite';` +
    `var v=window.__CN_THEME_VARS[id],r=document.documentElement;` +
    `for(var k in v)r.style.setProperty(k,v[k]);` +
    `r.dataset.theme=id;` +
    `}catch(e){}})();`;
  return <script dangerouslySetInnerHTML={{ __html: script }} />;
}
