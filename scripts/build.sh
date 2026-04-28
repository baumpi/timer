#!/usr/bin/env bash
# Build Timer BrainRead.app for Apple Silicon, no Xcode required (CLT only).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Wura Timer"
EXEC_NAME="TimerBrainRead"
BUNDLE_ID="at.wura.timer"
APP_DIR="$ROOT/build/$APP_NAME.app"

echo "==> Cleaning"
rm -rf "$APP_DIR" "$ROOT/build/$APP_NAME.dmg" "$ROOT/build/dmg-staging"
rm -rf "$ROOT/build/Timer BrainRead.app" "$ROOT/build/Timer BrainRead.dmg"
rm -rf .build

echo "==> Compiling Swift (release, arm64)"
swift build \
    --configuration release \
    --arch arm64 \
    --package-path "$ROOT"

EXEC_PATH="$ROOT/.build/arm64-apple-macosx/release/$EXEC_NAME"
if [[ ! -f "$EXEC_PATH" ]]; then
    echo "Build failed: $EXEC_PATH not found"; exit 1
fi

echo "==> Assembling .app bundle"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources/fonts"
cp "$EXEC_PATH"            "$APP_DIR/Contents/MacOS/$EXEC_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT/Resources/fonts/"*.otf "$APP_DIR/Contents/Resources/fonts/" 2>/dev/null || true
cp "$ROOT/Resources/fonts/"*.ttf "$APP_DIR/Contents/Resources/fonts/" 2>/dev/null || true
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi
echo "APPL????" > "$APP_DIR/Contents/PkgInfo"

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - --options runtime "$APP_DIR" || codesign --force --deep --sign - "$APP_DIR"

echo "==> Verifying"
file "$APP_DIR/Contents/MacOS/$EXEC_NAME" | grep -q "arm64" && echo "  arch: arm64 ✓"
codesign --verify --deep --strict "$APP_DIR" && echo "  signature: ok ✓"

echo "==> App built at: $APP_DIR"
