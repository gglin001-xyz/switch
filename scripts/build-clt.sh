#!/usr/bin/env bash
# Build an arm64 Switch.app for this Mac with Command Line Tools only.
# Xcode.app and Sparkle are not required.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME=Switch
BUILD_ROOT="$PROJECT_DIR/build/clt"
APP_PATH="$BUILD_ROOT/$APP_NAME.app"
INTERMEDIATES="$BUILD_ROOT/intermediates"
TOOLCHAIN_ROOT=/Library/Developer/CommandLineTools
SDK_PATH="$TOOLCHAIN_ROOT/SDKs/MacOSX26.5.sdk"
SWIFTC="$TOOLCHAIN_ROOT/usr/bin/swiftc"
CLANG="$TOOLCHAIN_ROOT/usr/bin/clang"
TARGET=arm64-apple-macosx14.0

for tool in "$SWIFTC" "$CLANG" /usr/bin/iconutil /usr/bin/codesign /usr/bin/plutil /usr/libexec/PlistBuddy; do
    if [[ ! -x "$tool" ]]; then
        echo "missing required tool: $tool" >&2
        echo "install Apple Command Line Tools with: xcode-select --install" >&2
        exit 1
    fi
done

if [[ ! -d "$SDK_PATH" ]]; then
    echo "missing the tested macOS SDK: $SDK_PATH" >&2
    exit 1
fi

rm -rf "$BUILD_ROOT"
mkdir -p \
    "$INTERMEDIATES" \
    "$APP_PATH/Contents/MacOS" \
    "$APP_PATH/Contents/Resources"

echo "==> Compiling Objective-C support"
"$CLANG" \
    -fobjc-arc \
    -fblocks \
    -target "$TARGET" \
    -isysroot "$SDK_PATH" \
    -mmacosx-version-min=14.0 \
    -c "$PROJECT_DIR/Sources/Switch/ObjCException.m" \
    -o "$INTERMEDIATES/ObjCException.o"

echo "==> Compiling arm64 application"
"$SWIFTC" \
    -swift-version 5 \
    -parse-as-library \
    -O \
    -whole-module-optimization \
    -sdk "$SDK_PATH" \
    -target "$TARGET" \
    -module-name "$APP_NAME" \
    -import-objc-header "$PROJECT_DIR/Sources/Switch/Switch-Bridging-Header.h" \
    -F /System/Library/PrivateFrameworks \
    -framework SkyLight \
    "$PROJECT_DIR"/Sources/Switch/*.swift \
    "$INTERMEDIATES/ObjCException.o" \
    -o "$APP_PATH/Contents/MacOS/$APP_NAME"

echo "==> Packaging application bundle"
cp "$PROJECT_DIR/Sources/Switch/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.sanyamgarg.switch" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_PATH/Contents/Info.plist"

ICON_SOURCE="$PROJECT_DIR/Sources/Switch/Resources/Assets.xcassets/AppIcon.appiconset"
ICONSET="$INTERMEDIATES/AppIcon.iconset"
mkdir -p "$ICONSET"
for icon in \
    icon_16x16.png \
    icon_16x16@2x.png \
    icon_32x32.png \
    icon_32x32@2x.png \
    icon_128x128.png \
    icon_128x128@2x.png \
    icon_256x256.png \
    icon_256x256@2x.png \
    icon_512x512.png \
    icon_512x512@2x.png; do
    cp "$ICON_SOURCE/$icon" "$ICONSET/$icon"
done
/usr/bin/iconutil -c icns "$ICONSET" -o "$APP_PATH/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"

echo "==> Applying local ad-hoc signature"
/usr/bin/codesign \
    --force \
    --sign - \
    --options runtime \
    --timestamp=none \
    --entitlements "$PROJECT_DIR/Sources/Switch/Resources/Switch.entitlements" \
    "$APP_PATH"

/usr/bin/codesign --verify --strict --verbose=2 "$APP_PATH"
/usr/bin/plutil -lint "$APP_PATH/Contents/Info.plist"

echo ""
echo "==> Built $APP_PATH"
/usr/bin/file "$APP_PATH/Contents/MacOS/$APP_NAME"
echo "==> Sparkle is intentionally excluded. Automatic updates are unavailable in this build."
