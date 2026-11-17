#!/usr/bin/env bash
# Builds build/Cambio.app: universal binary (Apple Silicon + Intel), icon, translations,
# ad-hoc signature. Usage: scripts/build-app.sh [version]
set -euo pipefail

VERSION="${1:-1.0.0}"
cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf build/Cambio.app
mkdir -p build/Cambio.app/Contents/MacOS build/Cambio.app/Contents/Resources
cp "$BIN_DIR/Cambio" build/Cambio.app/Contents/MacOS/Cambio
sed "s/__VERSION__/$VERSION/" Resources/Info.plist > build/Cambio.app/Contents/Info.plist
cp Resources/AppIcon.icns build/Cambio.app/Contents/Resources/
cp -R Resources/*.lproj build/Cambio.app/Contents/Resources/

codesign --force --options runtime --sign - build/Cambio.app
codesign --verify --strict build/Cambio.app
echo "Built build/Cambio.app ($VERSION)"
