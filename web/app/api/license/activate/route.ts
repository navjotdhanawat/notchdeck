import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db";

export const runtime = "edge";

export async function POST(req: NextRequest) {
  let key: string, machine_id: string;
  try {
    ({ key, machine_id } = await req.json());
  } catch {
    return NextResponse.json({ valid: false, reason: "bad_request" }, { status: 400 });
  }

  if (!key || !machine_id) {
    return NextResponse.json({ valid: false, reason: "bad_request" }, { status: 400 });
  }

  const row = await db.execute({
    sql: "SELECT key, machine_id, revoked FROM licenses WHERE key = ?",
    args: [key.toUpperCase().trim()],
  });

  if (row.rows.length === 0) {
    return NextResponse.json({ valid: false, reason: "invalid_key" });
  }

  const license = row.rows[0];

  if (license.revoked) {
    return NextResponse.json({ valid: false, reason: "revoked" });
  }

  // Already activated on a different machine
  if (license.machine_id && license.machine_id !== machine_id) {
    return NextResponse.json({ valid: false, reason: "already_activated" });
  }

  // First activation — lock to this machine
  if (!license.machine_id) {
    await db.execute({
      sql: "UPDATE licenses SET machine_id = ?, activated_at = datetime('now') WHERE key = ?",
      args: [machine_id, key.toUpperCase().trim()],
    });
  }

  return NextResponse.json({ valid: true, tier: "pro" });
}
