#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_DIR="$BUILD_DIR/Walking Buddy.app"
CONTENTS_DIR="$APP_DIR/Contents"

rm -rf "$BUILD_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"

xcrun swiftc "$PROJECT_DIR/Sources/WalkingBuddy.swift" \
  -o "$CONTENTS_DIR/MacOS/WalkingBuddy" \
  -framework AppKit \
  -framework QuartzCore

cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR"/Resources/*.png "$CONTENTS_DIR/Resources/"
chmod +x "$CONTENTS_DIR/MacOS/WalkingBuddy"
codesign --force --deep --sign - "$APP_DIR"

(
  cd "$BUILD_DIR"
  zip -qry -X "Walking-Buddy-macOS.zip" "Walking Buddy.app"
)
codesign --verify --deep --strict "$APP_DIR"

echo "Built: $APP_DIR"
echo "Archive: $BUILD_DIR/Walking-Buddy-macOS.zip"
