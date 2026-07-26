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
    sql: "SELECT machine_id, revoked FROM licenses WHERE key = ?",
    args: [key.toUpperCase().trim()],
  });

  if (row.rows.length === 0) {
    return NextResponse.json({ valid: false, reason: "invalid_key" });
  }

  const license = row.rows[0];

  if (license.revoked) {
    return NextResponse.json({ valid: false, reason: "revoked" });
  }

  if (license.machine_id !== machine_id) {
    return NextResponse.json({ valid: false, reason: "machine_mismatch" });
  }

  return NextResponse.json({ valid: true, tier: "pro" });
}
