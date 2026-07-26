import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db";
import { nanoid } from "nanoid";

export const runtime = "edge";

const ADMIN_SECRET = process.env.ADMIN_SECRET;

function generateKey(): string {
  // NDPRO-XXXX-XXXX-XXXX  (uppercase alphanumeric, no ambiguous chars)
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const seg = () => Array.from({ length: 4 }, () => chars[Math.floor(Math.random() * chars.length)]).join("");
  return `NDPRO-${seg()}-${seg()}-${seg()}`;
}

export async function POST(req: NextRequest) {
  if (!ADMIN_SECRET) {
    return NextResponse.json({ error: "admin not configured" }, { status: 500 });
  }
  if (req.headers.get("x-admin-secret") !== ADMIN_SECRET) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  let count = 1, notes = "";
  try {
    const body = await req.json();
    count = Math.min(Number(body.count) || 1, 100);
    notes = body.notes ?? "";
  } catch {}

  const keys: string[] = [];
  for (let i = 0; i < count; i++) {
    const key = generateKey();
    await db.execute({
      sql: "INSERT OR IGNORE INTO licenses (key, notes) VALUES (?, ?)",
      args: [key, notes],
    });
    keys.push(key);
  }

  return NextResponse.json({ keys });
}
