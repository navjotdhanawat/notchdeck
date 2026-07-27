#!/usr/bin/env bash
# NotchDeck Installer Script
# Usage: curl -fsSL https://notchdeck.app/api/install | bash
set -e

APP_NAME="NotchDeck"
INSTALL_DIR="/Applications"
DMG_PATH="/tmp/NotchDeck.dmg"
DOWNLOAD_URL="${NOTCHDECK_DOWNLOAD_URL:-https://github.com/navjotdhanawat/notchdeck/releases/latest/download/NotchDeck.dmg}"

# Check OS
if [[ "$(uname)" != "Darwin" ]]; then
  echo "Error: NotchDeck is only supported on macOS."
  exit 1
fi

echo ""
echo "=========================================="
echo "      NotchDeck macOS Installer           "
echo "=========================================="
echo ""
echo "  Downloading latest ${APP_NAME}..."
echo ""

# Download DMG
curl -fsSL --progress-bar "${DOWNLOAD_URL}" -o "${DMG_PATH}"

if [ ! -f "${DMG_PATH}" ]; then
  echo "Error: Download failed. Please try again or download manually from https://notchdeck.app"
  exit 1
fi

echo ""
echo "  Mounting disk image..."
MOUNT_POINT=$(hdiutil attach "${DMG_PATH}" -nobrowse | grep -o '/Volumes/.*' | head -n 1)

if [ -z "${MOUNT_POINT}" ] || [ ! -d "${MOUNT_POINT}/${APP_NAME}.app" ]; then
  echo "Error: Failed to mount disk image."
  rm -f "${DMG_PATH}"
  exit 1
fi

echo "  Installing to ${INSTALL_DIR}/${APP_NAME}.app..."
# If old app exists, remove it first
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
  rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi

cp -R "${MOUNT_POINT}/${APP_NAME}.app" "${INSTALL_DIR}/"

echo "  Unmounting disk image..."
hdiutil detach "${MOUNT_POINT}" -quiet

# Remove Gatekeeper quarantine flag so macOS doesn't block unsigned/ad-hoc app
xattr -dr com.apple.quarantine "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true

# Cleanup temp DMG
rm -f "${DMG_PATH}"

echo ""
echo "=========================================="
echo "  🎉 ${APP_NAME} successfully installed!"
echo "=========================================="
echo ""
echo "  Location: ${INSTALL_DIR}/${APP_NAME}.app"
echo ""
echo "  To launch NotchDeck, run:"
echo "    open ${INSTALL_DIR}/${APP_NAME}.app"
echo ""
