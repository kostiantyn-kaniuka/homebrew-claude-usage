#!/bin/bash
# Builds ClaudeUsage.app (helper + desktop widget) with only Apple's Command Line Tools.
# Usage: ./build.sh [output_dir]     (default: ./dist)
set -euo pipefail

cd "$(dirname "$0")"
OUT="${1:-dist}"
VERSION="${VERSION:-1.0.0}"
MIN_MACOS="14.0"
ARCH="$(uname -m)"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
TARGET="${ARCH}-apple-macos${MIN_MACOS}"

APP="$OUT/ClaudeUsage.app"
APPEX="$APP/Contents/PlugIns/ClaudeUsageWidget.appex"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APPEX/Contents/MacOS"

SWIFTC=(xcrun swiftc -O -swift-version 5 -parse-as-library -target "$TARGET" -sdk "$SDK")

echo "Compiling helper app…"
"${SWIFTC[@]}" App/*.swift Shared/*.swift -o "$APP/Contents/MacOS/ClaudeUsage"

echo "Compiling widget…"
"${SWIFTC[@]}" -application-extension Widget/*.swift Shared/*.swift \
  -Xlinker -application_extension -o "$APPEX/Contents/MacOS/ClaudeUsageWidget"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>ClaudeUsage</string>
  <key>CFBundleIdentifier</key><string>local.claudeusage.app</string>
  <key>CFBundleName</key><string>ClaudeUsage</string>
  <key>CFBundleDisplayName</key><string>Claude Usage</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF

cat > "$APPEX/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>ClaudeUsageWidget</string>
  <key>CFBundleIdentifier</key><string>local.claudeusage.app.widget</string>
  <key>CFBundleName</key><string>ClaudeUsageWidget</string>
  <key>CFBundleDisplayName</key><string>Claude Usage</string>
  <key>CFBundlePackageType</key><string>XPC!</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
  <key>NSExtension</key><dict>
    <key>NSExtensionPointIdentifier</key><string>com.apple.widgetkit-extension</string>
  </dict>
</dict></plist>
EOF

echo "Signing (local, ad-hoc)…"
codesign --force --sign - --entitlements Widget/Widget.entitlements "$APPEX"
codesign --force --sign - "$APP"

echo "Built $APP"
