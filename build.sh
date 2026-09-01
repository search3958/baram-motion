#!/bin/bash
set -e

APP_NAME="BaramMotion"
PROJECT_DIR="BaramMotion"
BUILD_DIR="build"
APP_BUILD_DIR="$BUILD_DIR/$APP_NAME.app"

cd "$(dirname "$0")"

echo "🔨 Building $APP_NAME..."

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

SDK=$(xcrun --sdk macosx --show-sdk-path)

swiftc \
    -sdk "$SDK" \
    -target arm64-apple-macos14.0 \
    -O \
    -framework AppKit \
    -o "$BUILD_DIR/$APP_NAME" \
    "$PROJECT_DIR/Sources/main.swift" \
    "$PROJECT_DIR/Sources/AppDelegate.swift" \
    "$PROJECT_DIR/Sources/MainViewController.swift"

echo "📦 Creating app bundle..."

CONTENTS="$APP_BUILD_DIR/Contents"
MACOS="$CONTENTS/MacOS"

mkdir -p "$MACOS"

mkdir -p "$CONTENTS/Resources"
cp "$PROJECT_DIR/Resources/appicon.icns" "$CONTENTS/Resources/"

cp "$BUILD_DIR/$APP_NAME" "$MACOS/"
cp "$PROJECT_DIR/Info.plist" "$CONTENTS/"

echo "✅ Build complete: $APP_BUILD_DIR"

echo "🚀 Launching $APP_NAME... (Ctrl+C to stop)"

open "$APP_BUILD_DIR"

# Wait for app to appear, then activate it
for i in $(seq 1 10); do
    sleep 0.5
    if pgrep -f "$APP_NAME" > /dev/null 2>&1; then
        osascript -e "tell application \"$APP_NAME\" to activate" 2>/dev/null || true
        break
    fi
done

trap 'echo ""; echo "🛑 Stopping $APP_NAME..."; pkill -f "$APP_NAME"; echo "✅ Stopped."; exit 0' INT TERM

while true; do
    sleep 1
done
