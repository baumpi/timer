#!/usr/bin/env bash
# Package Timer BrainRead.app into a drag-to-Applications DMG using built-in hdiutil.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Wura Timer"
APP_DIR="$ROOT/build/$APP_NAME.app"
DMG_PATH="$ROOT/build/$APP_NAME.dmg"
STAGE="$ROOT/build/dmg-staging"

if [[ ! -d "$APP_DIR" ]]; then
    echo "App not found: $APP_DIR — run scripts/build.sh first."; exit 1
fi

echo "==> Staging DMG contents"
rm -rf "$STAGE" "$DMG_PATH"
mkdir -p "$STAGE"
cp -R "$APP_DIR" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGE"
echo "==> DMG: $DMG_PATH"
ls -lh "$DMG_PATH"
