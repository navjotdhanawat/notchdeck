"use client";

import { useEffect } from "react";

export function Analytics() {
  useEffect(() => {
    // Fire-and-forget — never block anything on this
    fetch("/api/analytics/visit", { method: "POST" }).catch(() => {});
  }, []);

  return null;
}
