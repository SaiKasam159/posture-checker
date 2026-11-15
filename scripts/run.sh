#!/bin/bash
# Builds Apollo and runs it as a real .app bundle, so Info.plist settings
# (menu-bar-only, camera usage string) and the system permission dialogs
# behave the way they will in the shipped app.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="debug"
swift build -c "$CONFIG"

APP_DIR="build/Apollo.app"
BIN_PATH=".build/${CONFIG}/Apollo"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/Apollo"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"

echo "Built $APP_DIR"
open "$APP_DIR"
