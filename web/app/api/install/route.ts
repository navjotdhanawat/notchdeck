import { NextResponse } from "next/server";

export const runtime = "edge";

function getScript(downloadUrl: string) {
  return `#!/bin/bash
set -e

APP_NAME="NotchDeck"
INSTALL_DIR="/Applications"
DMG_PATH="/tmp/NotchDeck.dmg"
DOWNLOAD_URL="${downloadUrl}"

echo ""
echo "  Installing \${APP_NAME}..."
echo ""

# Download
curl -fsSL --progress-bar "\${DOWNLOAD_URL}" -o "\${DMG_PATH}"

# Mount
MOUNT_POINT=\$(hdiutil attach "\${DMG_PATH}" -nobrowse -quiet | tail -1 | awk '{print \$NF}')

# Copy
cp -R "\${MOUNT_POINT}/\${APP_NAME}.app" "\${INSTALL_DIR}/"

# Unmount
hdiutil detach "\${MOUNT_POINT}" -quiet

# Remove quarantine so Gatekeeper doesn't block it
xattr -dr com.apple.quarantine "\${INSTALL_DIR}/\${APP_NAME}.app" 2>/dev/null || true

# Cleanup
rm -f "\${DMG_PATH}"

echo ""
echo "  \${APP_NAME} installed to \${INSTALL_DIR}/\${APP_NAME}.app"
echo ""
echo "  Open it from Launchpad or run:"
echo "    open \${INSTALL_DIR}/\${APP_NAME}.app"
echo ""
`;
}

export async function GET(_req: NextRequest) {
  const base = process.env.NEXT_PUBLIC_SITE_URL ?? "https://notchdeck.app";
  const downloadUrl = `${base}/api/download`;

  return new NextResponse(getScript(downloadUrl), {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}
