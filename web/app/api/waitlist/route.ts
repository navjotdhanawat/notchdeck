import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db";

export const runtime = "edge";

export async function POST(req: NextRequest) {
  let email: string, twitter: string | undefined, source: string;
  try {
    ({ email, twitter, source = "landing" } = await req.json());
  } catch {
    return NextResponse.json({ error: "bad_request" }, { status: 400 });
  }

  if (!email || !email.includes("@")) {
    return NextResponse.json({ error: "invalid_email" }, { status: 400 });
  }

  try {
    await db.execute({
      sql: "INSERT INTO waitlist (email, twitter, source) VALUES (?, ?, ?)",
      args: [email.toLowerCase().trim(), twitter?.trim() ?? null, source],
    });
    return NextResponse.json({ ok: true });
  } catch (e: any) {
    // UNIQUE constraint = already signed up
    if (e?.message?.includes("UNIQUE")) {
      return NextResponse.json({ ok: true, already: true });
    }
    throw e;
  }
}
