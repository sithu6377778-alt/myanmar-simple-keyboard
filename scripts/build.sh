#!/bin/bash
# Builds MyanmarSimpleKeyboard.app (Apple Silicon + Intel) and the .pkg installer.
#   VERSION=0.1.0 scripts/build.sh
# Output: build/MyanmarSimpleKeyboard-<version>.pkg
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.2}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
MIN_MACOS="15.0"
NAME="MyanmarSimpleKeyboard"
PKG_ID="com.linnlabs.inputmethod.MyanmarSimple.pkg"
BUILD="build"
ROOT="$BUILD/pkgroot"
APP="$ROOT/Library/Input Methods/$NAME.app"
SDK="$(xcrun --sdk macosx --show-sdk-path)"

rm -rf "$ROOT" "$BUILD/obj" "$BUILD"/*.pkg
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD/obj"

echo "==> Compiling (arm64 + x86_64, macOS $MIN_MACOS+)"
for arch in arm64 x86_64; do
  xcrun swiftc -O -whole-module-optimization \
    -sdk "$SDK" -target "$arch-apple-macos$MIN_MACOS" \
    -module-name "$NAME" \
    -framework Cocoa -framework InputMethodKit -framework Carbon \
    Sources/Core/*.swift Sources/App/*.swift \
    -o "$BUILD/obj/$NAME-$arch"
done
lipo -create -output "$APP/Contents/MacOS/$NAME" "$BUILD/obj/$NAME-arm64" "$BUILD/obj/$NAME-x86_64"
lipo -info "$APP/Contents/MacOS/$NAME"

echo "==> Bundle resources"
sed -e "s/__VERSION__/$VERSION/g" -e "s/__BUILD__/$BUILD_NUMBER/g" Resources/Info.plist > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"
cp -R Resources/en.lproj Resources/my.lproj "$APP/Contents/Resources/"
plutil -lint "$APP/Contents/Resources/en.lproj/InfoPlist.strings"
swift scripts/make-icon.swift "$APP/Contents/Resources/icon.tiff" "$BUILD/icon-preview.png"

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Installer package"
pkgbuild --analyze --root "$ROOT" "$BUILD/component.plist"
# Always install to /Library/Input Methods (never "relocate" to another copy).
plutil -replace 0.BundleIsRelocatable -bool NO "$BUILD/component.plist"
chmod 755 pkg/scripts/postinstall
pkgbuild --root "$ROOT" \
  --component-plist "$BUILD/component.plist" \
  --identifier "$PKG_ID" --version "$VERSION" \
  --install-location / --scripts pkg/scripts \
  "$BUILD/component.pkg"
sed -e "s/__VERSION__/$VERSION/g" pkg/Distribution.xml > "$BUILD/Distribution.xml"
productbuild --distribution "$BUILD/Distribution.xml" \
  --resources pkg/resources --package-path "$BUILD" \
  "$BUILD/$NAME-$VERSION.pkg"
rm -f "$BUILD/component.pkg"

ls -lh "$BUILD/$NAME-$VERSION.pkg"
shasum -a 256 "$BUILD/$NAME-$VERSION.pkg"
echo "==> Done"
