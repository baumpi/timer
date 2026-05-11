#!/usr/bin/env bash
# Build a SIDE-BY-SIDE dev copy of Wura Timer with bundle ID at.wura.timer.dev.
# Use this while the production app is running live (e.g. in a workshop) so
# nothing in /Applications and no LaunchServices entry is touched.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Wura Timer (Dev)"
EXEC_NAME="TimerBrainRead"
BUNDLE_ID="at.wura.timer.dev"
APP_DIR="$ROOT/build-dev/$APP_NAME.app"

echo "==> Cleaning dev artifacts only (production build/ untouched)"
rm -rf "$APP_DIR"
# Don't wipe .build — keep incremental builds fast across dev iterations.

echo "==> Compiling Swift (release, arm64)"
swift build \
    --configuration release \
    --arch arm64 \
    --package-path "$ROOT"

EXEC_PATH="$ROOT/.build/arm64-apple-macosx/release/$EXEC_NAME"
if [[ ! -f "$EXEC_PATH" ]]; then
    echo "Build failed: $EXEC_PATH not found"; exit 1
fi

echo "==> Assembling .app bundle ($BUNDLE_ID)"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources/fonts"
cp "$EXEC_PATH"                       "$APP_DIR/Contents/MacOS/$EXEC_NAME"
cp "$ROOT/Resources/Info-Dev.plist"   "$APP_DIR/Contents/Info.plist"
cp "$ROOT/Resources/fonts/"*.otf      "$APP_DIR/Contents/Resources/fonts/" 2>/dev/null || true
cp "$ROOT/Resources/fonts/"*.ttf      "$APP_DIR/Contents/Resources/fonts/" 2>/dev/null || true
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi
echo "APPL????" > "$APP_DIR/Contents/PkgInfo"

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - --options runtime "$APP_DIR" || codesign --force --deep --sign - "$APP_DIR"

echo "==> Verifying"
file "$APP_DIR/Contents/MacOS/$EXEC_NAME" | grep -q "arm64" && echo "  arch: arm64 ✓"
codesign --verify --deep --strict "$APP_DIR" && echo "  signature: ok ✓"

echo "==> Dev app built at: $APP_DIR"
echo "    Open with:  open \"$APP_DIR\""
