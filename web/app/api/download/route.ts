import { NextResponse } from "next/server";

const DOWNLOAD_URL = process.env.NOTCHDECK_DOWNLOAD_URL;
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;

// Cannot use edge runtime — streaming a proxied binary requires Node.js runtime
export const runtime = "nodejs";

export async function GET() {
  if (!DOWNLOAD_URL) {
    return NextResponse.json({ error: "download not configured" }, { status: 503 });
  }

  const headers: Record<string, string> = {
    Accept: "application/octet-stream",
  };

  // Private repo: authenticate with a read-only token
  if (GITHUB_TOKEN) {
    headers["Authorization"] = `Bearer ${GITHUB_TOKEN}`;
  }

  const upstream = await fetch(DOWNLOAD_URL, { headers });

  if (!upstream.ok) {
    return NextResponse.json(
      { error: `upstream error: ${upstream.status}` },
      { status: 502 }
    );
  }

  return new NextResponse(upstream.body, {
    status: 200,
    headers: {
      "Content-Type": "application/octet-stream",
      "Content-Disposition": 'attachment; filename="NotchDeck.dmg"',
      "Cache-Control": "no-store",
    },
  });
}
