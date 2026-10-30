#!/usr/bin/env bash
# ==============================================================================
# packaging/linux/package-deb.sh - Debian / Ubuntu (.deb) Package Builder
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERSION="${1:-0.2.0}"
OUTPUT_DIR="${2:-$ROOT_DIR/dist/linux}"

echo "==> [deb] Building Debian/Ubuntu package for ChessPasant v${VERSION}..."

BUNDLE_DIR="$ROOT_DIR/apps/app/build/linux/x64/release/bundle"
if [ ! -d "$BUNDLE_DIR" ]; then
  echo "ERROR: Flutter Linux release bundle not found at $BUNDLE_DIR"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
WORK_DIR=$(mktemp -d -t chesspasant-deb-XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

DEB_ROOT="$WORK_DIR/chesspasant_${VERSION}_amd64"
mkdir -p "$DEB_ROOT/DEBIAN"
mkdir -p "$DEB_ROOT/usr/bin"
mkdir -p "$DEB_ROOT/usr/lib/chesspasant"
mkdir -p "$DEB_ROOT/usr/share/applications"
mkdir -p "$DEB_ROOT/usr/share/icons/hicolor/512x512/apps"
mkdir -p "$DEB_ROOT/usr/share/icons/hicolor/128x128/apps"
mkdir -p "$DEB_ROOT/usr/share/icons/hicolor/32x32/apps"

# 1. Install Flutter bundle
cp -r "$BUNDLE_DIR"/* "$DEB_ROOT/usr/lib/chesspasant/"
chmod 755 "$DEB_ROOT/usr/lib/chesspasant/chesspasant"

# 2. Binary wrapper
cat << 'EOF' > "$DEB_ROOT/usr/bin/chesspasant"
#!/bin/sh
exec /usr/lib/chesspasant/chesspasant "$@"
EOF
chmod 755 "$DEB_ROOT/usr/bin/chesspasant"

# 3. Desktop entry
cp "$ROOT_DIR/packaging/arch/chesspasant.desktop" "$DEB_ROOT/usr/share/applications/chesspasant.desktop"
chmod 644 "$DEB_ROOT/usr/share/applications/chesspasant.desktop"

# 4. Icons
ICONS_DIR="$ROOT_DIR/apps/desktop/src-tauri/icons"
if [ -f "$ICONS_DIR/icon.png" ]; then
  cp "$ICONS_DIR/icon.png" "$DEB_ROOT/usr/share/icons/hicolor/512x512/apps/chesspasant.png"
fi
if [ -f "$ICONS_DIR/128x128.png" ]; then
  cp "$ICONS_DIR/128x128.png" "$DEB_ROOT/usr/share/icons/hicolor/128x128/apps/chesspasant.png"
fi
if [ -f "$ICONS_DIR/32x32.png" ]; then
  cp "$ICONS_DIR/32x32.png" "$DEB_ROOT/usr/share/icons/hicolor/32x32/apps/chesspasant.png"
fi

# Compute installed size (in KB)
INSTALLED_SIZE=$(du -sk "$DEB_ROOT" | cut -f1)

# 5. Control file
cat << EOF > "$DEB_ROOT/DEBIAN/control"
Package: chesspasant
Version: ${VERSION}
Section: games
Priority: optional
Architecture: amd64
Installed-Size: ${INSTALLED_SIZE}
Depends: libgtk-3-0, libglib2.0-0, libgstreamer1.0-0, libgstreamer-plugins-base1.0-0
Maintainer: Yogesh Kumar Mallik <yogeshkumarmallikdev@gmail.com>
Homepage: https://github.com/Yogesh-Kumar-Mallik-dev/ChessPasant
Description: Authentic Acoustic Chess Platform
 ChessPasant is a modern, high-performance acoustic chess platform
 engineered with Flutter and Go.
EOF

# 6. Build .deb package
dpkg-deb --build --root-owner-group "$DEB_ROOT" "$OUTPUT_DIR/chesspasant_${VERSION}_amd64.deb"
echo "✅ [deb] Successfully built: $OUTPUT_DIR/chesspasant_${VERSION}_amd64.deb"
