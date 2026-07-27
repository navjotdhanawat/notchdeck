#!/usr/bin/env bash
set -euo pipefail

# Make sure we're in the repository root
cd "$(dirname "$0")/.."

echo "Building NotchDeck in release mode..."
swift build -c release

# Output dirs
APP_DIR="NotchDeck.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

# Clear any old app folder
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"

echo "Packaging binaries..."
cp .build/release/NotchDeckApp "${MACOS_DIR}/"
cp .build/release/notch-bridge "${MACOS_DIR}/"

echo "Creating Info.plist..."
cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>NotchDeckApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.navjotdhanawat.NotchDeck</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>NotchDeck</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Applying ad-hoc code signature..."
codesign --force --deep --sign - "${APP_DIR}"

# Strip quarantine flag locally if we run it
xattr -dr com.apple.quarantine "${APP_DIR}" 2>/dev/null || true

echo "Creating DMG..."
rm -f NotchDeck.dmg
hdiutil create -volname "NotchDeck" -srcfolder "${APP_DIR}" -ov -format UDZO NotchDeck.dmg

echo "NotchDeck.dmg created successfully!"

