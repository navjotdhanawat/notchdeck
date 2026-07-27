import { track } from "@vercel/analytics";

/**
 * Safe wrapper around @vercel/analytics track function.
 */
export function trackEvent(eventName: string, properties?: Record<string, string | number | boolean>) {
  try {
    track(eventName, properties);
  } catch (error) {
    // Fail silently in development if tracking is restricted or errors
    if (process.env.NODE_ENV === "development") {
      console.debug(`[Analytics] Track event "${eventName}":`, properties, error);
    }
  }
}

/** Track when user opens the Download modal */
export function trackOpenDownloadModal(source: string) {
  trackEvent("open_download_modal", { source });
}

/** Track install method tab selections (brew | curl | dmg) */
export function trackSelectInstallTab(tab: "brew" | "curl" | "dmg") {
  trackEvent("select_install_tab", { tab });
}

/** Track when user copies an install command */
export function trackCopyInstallCommand(method: "brew" | "curl") {
  trackEvent("copy_install_command", { method });
}

/** Track direct DMG download trigger */
export function trackTriggerDmgDownload(source: string = "modal") {
  trackEvent("trigger_dmg_download", { source });
}

/** Track sponsor link clicks */
export function trackSponsorClick(source: string) {
  trackEvent("sponsor_click", { source });
}

/** Track waitlist email submissions */
export function trackWaitlistSubmit(source: string, status: "success" | "already" | "error") {
  trackEvent("waitlist_submit", { source, status });
}

/** Track theme changes */
export function trackThemeChange(themeId: string, source: "switcher" | "gallery") {
  trackEvent("theme_change", { themeId, source });
}

/** Track outbound link clicks (GitHub, Twitter, Coffee, etc.) */
export function trackOutboundClick(destination: string, location: string) {
  trackEvent("outbound_click", { destination, location });
}
