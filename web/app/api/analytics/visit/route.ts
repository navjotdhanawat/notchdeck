import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db";

export const runtime = "edge";

export async function POST(req: NextRequest) {
  // Best-effort — never block the page on this
  try {
    const country = req.headers.get("x-vercel-ip-country") ?? null;
    const city = req.headers.get("x-vercel-ip-city") ?? null;
    const referrer = req.headers.get("referer") ?? null;
    const user_agent = req.headers.get("user-agent") ?? null;

    await db.execute({
      sql: "INSERT INTO analytics (country, city, referrer, user_agent) VALUES (?, ?, ?, ?)",
      args: [country, city, referrer, user_agent],
    });
  } catch {}

  return new NextResponse(null, { status: 204 });
}
