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

SWIFT_SOURCES=$(find "$PROJECT_DIR/Sources" -type f -name "*.swift" | sort)

if [ -z "$SWIFT_SOURCES" ]; then
    echo "❌ No Swift source files found."
    exit 1
fi

echo "📚 Swift source files:"
echo "$SWIFT_SOURCES"

swiftc \
    -sdk "$SDK" \
    -target arm64-apple-macos14.0 \
    -O \
    -framework AppKit \
    -framework SwiftUI \
    -o "$BUILD_DIR/$APP_NAME" \
    $SWIFT_SOURCES

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
