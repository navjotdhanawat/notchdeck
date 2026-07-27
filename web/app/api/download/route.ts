import { NextResponse } from "next/server";

const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
// Default repository to fetch from
const REPO = "navjotdhanawat/notchdeck";

export const runtime = "nodejs";

interface GitHubAsset {
  name: string;
  url: string;
}

interface GitHubReleaseResponse {
  assets?: GitHubAsset[];
}

export async function GET() {
  if (!GITHUB_TOKEN) {
    return NextResponse.json({ error: "GITHUB_TOKEN is not configured" }, { status: 503 });
  }

  const authHeaders = {
    Authorization: `Bearer ${GITHUB_TOKEN}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
  };

  try {
    // 1. Fetch latest release info from GitHub API
    const releaseRes = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, {
      headers: authHeaders,
    });

    if (!releaseRes.ok) {
      return NextResponse.json(
        { error: `failed to get latest release: ${releaseRes.statusText}` },
        { status: 502 }
      );
    }

    const releaseData = (await releaseRes.json()) as GitHubReleaseResponse;
    const assets = releaseData.assets || [];

    // 2. Find NotchDeck.dmg asset
    const dmgAsset = assets.find((asset) => asset.name === "NotchDeck.dmg");

    if (!dmgAsset) {
      return NextResponse.json({ error: "NotchDeck.dmg not found in latest release" }, { status: 404 });
    }

    // 3. Request the raw asset binary using the asset API URL
    const assetRes = await fetch(dmgAsset.url, {
      headers: {
        Authorization: `Bearer ${GITHUB_TOKEN}`,
        Accept: "application/octet-stream",
        "X-GitHub-Api-Version": "2022-11-28",
      },
    });

    if (!assetRes.ok) {
      return NextResponse.json(
        { error: `failed to download asset: ${assetRes.statusText}` },
        { status: 502 }
      );
    }

    // 4. Return the stream response
    return new NextResponse(assetRes.body, {
      status: 200,
      headers: {
        "Content-Type": "application/octet-stream",
        "Content-Disposition": 'attachment; filename="NotchDeck.dmg"',
        "Cache-Control": "no-store",
      },
    });
  } catch (error: any) {
    return NextResponse.json({ error: error.message || "internal server error" }, { status: 500 });
  }
}
