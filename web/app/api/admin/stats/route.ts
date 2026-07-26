import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db";

export const runtime = "edge";

const ADMIN_SECRET = process.env.ADMIN_SECRET;

export async function GET(req: NextRequest) {
  if (!ADMIN_SECRET) {
    return NextResponse.json({ error: "admin not configured" }, { status: 500 });
  }
  if (req.headers.get("x-admin-secret") !== ADMIN_SECRET) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const [visits, countries, waitlistCount, licenses] = await Promise.all([
    db.execute("SELECT COUNT(*) as total FROM analytics"),
    db.execute(
      "SELECT country, COUNT(*) as cnt FROM analytics WHERE country IS NOT NULL GROUP BY country ORDER BY cnt DESC LIMIT 10"
    ),
    db.execute("SELECT COUNT(*) as total FROM waitlist"),
    db.execute(
      "SELECT COUNT(*) as total, SUM(CASE WHEN machine_id IS NOT NULL THEN 1 ELSE 0 END) as activated, SUM(revoked) as revoked FROM licenses"
    ),
  ]);

  return NextResponse.json({
    visits: {
      total: visits.rows[0].total,
      topCountries: countries.rows.map((r: Record<string, unknown>) => ({ country: r.country, count: r.cnt })),
    },
    waitlist: { total: waitlistCount.rows[0].total },
    licenses: {
      total: licenses.rows[0].total,
      activated: licenses.rows[0].activated,
      revoked: licenses.rows[0].revoked,
    },
  });
}
