#!/bin/bash
#
# Builds DevSim.app.
#
#   Scripts/build-app.sh             build into ./build
#   Scripts/build-app.sh --install   build, then install into /Applications
#
set -euo pipefail

VERSION="2.0.0"          # keep in sync with AppInfo.fallbackVersion
BUILD_NUMBER="1"
BUNDLE_ID="dev.devsim.DevSim"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/DevSim.app"
INSTALL=false

for argument in "$@"; do
    case "$argument" in
        --install) INSTALL=true ;;
        *) echo "unknown option: $argument" >&2; exit 1 ;;
    esac
done

echo "==> Compiling (release)"
swift build -c release
BINARY="$(swift build -c release --show-bin-path)/DevSim"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/DevSim"

echo "==> Rendering app icon"
ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
swift "$ROOT/Scripts/make-icon.swift" "$ICONSET"
iconutil --convert icns --output "$APP/Contents/Resources/AppIcon.icns" "$ICONSET"
rm -rf "$ICONSET"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>DevSim</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>DevSim</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>MIT licensed.</string>
</dict>
</plist>
PLIST

echo "==> Signing (ad-hoc)"
# Extended attributes picked up while copying make codesign refuse the bundle.
xattr -cr "$APP"
codesign --force --sign - --timestamp=none "$APP"

if [ "$INSTALL" = true ]; then
    echo "==> Installing to /Applications"
    # A running copy holds its bundle open; stop it first.
    pkill -x DevSim 2>/dev/null || true
    rm -rf "/Applications/DevSim.app"
    cp -R "$APP" "/Applications/DevSim.app"
    echo "==> Launching"
    open "/Applications/DevSim.app"
else
    echo
    echo "Built $APP"
    echo "Run it with:  open \"$APP\""
fi
