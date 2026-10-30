#!/usr/bin/env bash
# ==============================================================================
# packaging/arch/package-arch.sh - Arch Linux Package (.pkg.tar.zst & .tar.gz) Builder
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERSION="${1:-0.1.9}"
OUTPUT_DIR="${2:-$ROOT_DIR/dist/arch}"

echo "==> [arch] Building Arch Linux release package for ChessPasant v${VERSION}..."

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
WORK_DIR=$(mktemp -d -t chesspasant-arch-build-XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

# Locate compiled binary
BINARY_PATH=""
CANDIDATE_PATHS=(
    "$ROOT_DIR/apps/app/build/linux/x64/release/bundle/chesspasant"
    "$ROOT_DIR/apps/desktop/src-tauri/target/release/chesspasant"
    "$ROOT_DIR/apps/desktop/src-tauri/target/release/ChessPasant"
    "$ROOT_DIR/apps/desktop/src-tauri/target/debug/chesspasant"
    "$ROOT_DIR/apps/desktop/src-tauri/target/debug/ChessPasant"
    "$ROOT_DIR/apps/desktop/src-tauri/target/release/bundle/deb"
)

for p in "${CANDIDATE_PATHS[@]}"; do
    if [ -f "$p" ]; then
        BINARY_PATH="$p"
        break
    fi
done

if [ -z "$BINARY_PATH" ] && [ -d "${CANDIDATE_PATHS[4]}" ]; then
    DEB_FILE=$(find "${CANDIDATE_PATHS[4]}" -name "*.deb" | head -n 1)
    if [ -n "$DEB_FILE" ]; then
        echo "==> [arch] Extracting binary from built deb bundle: $DEB_FILE"
        dpkg-deb -x "$DEB_FILE" "$WORK_DIR/deb_extract" || ar x "$DEB_FILE" --output="$WORK_DIR/deb_extract"
        BINARY_PATH=$(find "$WORK_DIR/deb_extract/usr/bin" -type f | head -n 1)
    fi
fi

# If force rebuild or binary not found, build via desktop release
if [ "${FORCE_REBUILD:-0}" = "1" ] || [ -z "$BINARY_PATH" ] || [ ! -f "$BINARY_PATH" ]; then
    if [ -d "$ROOT_DIR/apps/app" ]; then
        echo "==> [arch] Building Flutter native release bundle..."
        "$ROOT_DIR/scripts/app.sh" build
        BINARY_PATH="$ROOT_DIR/apps/app/build/linux/x64/release/bundle/chesspasant"
    else
        echo "==> [arch] Building desktop via npm/cargo..."
        cd "$ROOT_DIR/apps/desktop"
        npm run build -- --no-bundle
        BINARY_PATH="$ROOT_DIR/apps/desktop/src-tauri/target/release/chesspasant"
        if [ ! -f "$BINARY_PATH" ]; then
            BINARY_PATH="$ROOT_DIR/apps/desktop/src-tauri/target/release/ChessPasant"
        fi
    fi
fi

if [ ! -f "$BINARY_PATH" ]; then
    echo "ERROR: Unable to locate compiled ChessPasant desktop binary at $BINARY_PATH"
    exit 1
fi

echo "==> [arch] Using compiled binary: $BINARY_PATH"

PKG_DIR="$WORK_DIR/pkg"
mkdir -p "$PKG_DIR/usr/bin"
mkdir -p "$PKG_DIR/usr/share/applications"
mkdir -p "$PKG_DIR/usr/share/icons/hicolor/512x512/apps"
mkdir -p "$PKG_DIR/usr/share/icons/hicolor/128x128/apps"
mkdir -p "$PKG_DIR/usr/share/icons/hicolor/32x32/apps"

# 1. Install binary / Flutter bundle
if [ -d "$(dirname "$BINARY_PATH")/data" ]; then
    echo "==> [arch] Installing Flutter release bundle to /usr/lib/chesspasant..."
    mkdir -p "$PKG_DIR/usr/lib/chesspasant"
    cp -r "$(dirname "$BINARY_PATH")"/* "$PKG_DIR/usr/lib/chesspasant/"
    chmod 755 "$PKG_DIR/usr/lib/chesspasant/chesspasant"
    cat << 'EOF' > "$PKG_DIR/usr/bin/chesspasant"
#!/bin/sh
exec /usr/lib/chesspasant/chesspasant "$@"
EOF
    chmod 755 "$PKG_DIR/usr/bin/chesspasant"
else
    cp "$BINARY_PATH" "$PKG_DIR/usr/bin/chesspasant"
    chmod 755 "$PKG_DIR/usr/bin/chesspasant"
fi

# 1b. Install bundled Stockfish 19 NNUE engine
mkdir -p "$PKG_DIR/usr/lib/chesspasant"
if [ -f "$ROOT_DIR/apps/server/bin/stockfish" ]; then
    cp "$ROOT_DIR/apps/server/bin/stockfish" "$PKG_DIR/usr/lib/chesspasant/stockfish"
    chmod 755 "$PKG_DIR/usr/lib/chesspasant/stockfish"
elif [ -f "$ROOT_DIR/apps/desktop/src-tauri/bin/stockfish" ]; then
    cp "$ROOT_DIR/apps/desktop/src-tauri/bin/stockfish" "$PKG_DIR/usr/lib/chesspasant/stockfish"
    chmod 755 "$PKG_DIR/usr/lib/chesspasant/stockfish"
fi

# 2. Install desktop entry
cp "$SCRIPT_DIR/chesspasant.desktop" "$PKG_DIR/usr/share/applications/chesspasant.desktop"
chmod 644 "$PKG_DIR/usr/share/applications/chesspasant.desktop"

# 3. Install icons from desktop icons directory
ICONS_DIR="$ROOT_DIR/apps/desktop/src-tauri/icons"
if [ -f "$ICONS_DIR/icon.png" ]; then
    cp "$ICONS_DIR/icon.png" "$PKG_DIR/usr/share/icons/hicolor/512x512/apps/chesspasant.png"
fi
if [ -f "$ICONS_DIR/128x128.png" ]; then
    cp "$ICONS_DIR/128x128.png" "$PKG_DIR/usr/share/icons/hicolor/128x128/apps/chesspasant.png"
fi
if [ -f "$ICONS_DIR/32x32.png" ]; then
    cp "$ICONS_DIR/32x32.png" "$PKG_DIR/usr/share/icons/hicolor/32x32/apps/chesspasant.png"
fi

# Compute installed size in bytes
INSTALLED_SIZE=$(du -sb "$PKG_DIR" | cut -f1)
BUILD_DATE=$(date +%s)

# 4. Generate .PKGINFO metadata conforming to Arch pacman standard
cat <<EOF > "$PKG_DIR/.PKGINFO"
pkgname = chesspasant
pkgbase = chesspasant
pkgver = ${VERSION}-1
pkgdesc = Modern, distraction-free chess platform and Stockfish 19 Game Review Studio
url = https://github.com/Yogesh-Kumar-Mallik-dev/ChessPasant
builddate = ${BUILD_DATE}
packager = Yogesh Kumar Mallik <yogeshkumarmallikdev@gmail.com>
size = ${INSTALLED_SIZE}
arch = x86_64
license = MIT
depend = gtk3
depend = glib2
depend = openssl
EOF

if [ ! -d "$(dirname "$BINARY_PATH")/data" ]; then
    echo "depend = webkit2gtk-4.1" >> "$PKG_DIR/.PKGINFO"
fi

cat <<EOF >> "$PKG_DIR/.PKGINFO"
optdepend = stockfish: external UCI engine analysis
provides = chesspasant
conflict = chesspasant
EOF

# 5. Pack Arch Linux .pkg.tar.zst package
PKG_FILE="$OUTPUT_DIR/chesspasant-${VERSION}-1-x86_64.pkg.tar.zst"
echo "==> [arch] Creating Pacman package: $PKG_FILE"
cd "$PKG_DIR"
# Pacman requires .PKGINFO to be the first file entry
tar --zstd -cf "$PKG_FILE" .PKGINFO usr/

# 6. Also create a portable standalone tarball for manual installs or AUR
TAR_DIR="$WORK_DIR/tarball/chesspasant-${VERSION}"
mkdir -p "$TAR_DIR/icons"
cp "$BINARY_PATH" "$TAR_DIR/chesspasant"
if [ -f "$PKG_DIR/usr/lib/chesspasant/stockfish" ]; then
    cp "$PKG_DIR/usr/lib/chesspasant/stockfish" "$TAR_DIR/stockfish"
fi
cp "$SCRIPT_DIR/chesspasant.desktop" "$TAR_DIR/"
cp "$PKG_DIR/usr/share/icons/hicolor/512x512/apps/chesspasant.png" "$TAR_DIR/icons/512x512.png" || true
cp "$PKG_DIR/usr/share/icons/hicolor/128x128/apps/chesspasant.png" "$TAR_DIR/icons/128x128.png" || true
cp "$PKG_DIR/usr/share/icons/hicolor/32x32/apps/chesspasant.png" "$TAR_DIR/icons/32x32.png" || true

cat << 'EOF' > "$TAR_DIR/install.sh"
#!/usr/bin/env bash
set -e
PREFIX="${PREFIX:-/usr/local}"
echo "Installing ChessPasant to $PREFIX..."
install -Dm755 chesspasant "$PREFIX/bin/chesspasant"
if [ -f "stockfish" ]; then
    install -Dm755 stockfish "$PREFIX/lib/chesspasant/stockfish"
fi
install -Dm644 chesspasant.desktop "$PREFIX/share/applications/chesspasant.desktop"
if [ -d "icons" ]; then
    install -Dm644 icons/512x512.png "$PREFIX/share/icons/hicolor/512x512/apps/chesspasant.png" 2>/dev/null || true
    install -Dm644 icons/128x128.png "$PREFIX/share/icons/hicolor/128x128/apps/chesspasant.png" 2>/dev/null || true
    install -Dm644 icons/32x32.png "$PREFIX/share/icons/hicolor/32x32/apps/chesspasant.png" 2>/dev/null || true
fi
echo "ChessPasant installed successfully! Run 'chesspasant' to launch."
EOF
chmod +x "$TAR_DIR/install.sh"

TAR_FILE="$OUTPUT_DIR/ChessPasant_${VERSION}_x86_64.tar.gz"
echo "==> [arch] Creating standalone archive: $TAR_FILE"
cd "$WORK_DIR/tarball"
tar -czf "$TAR_FILE" "chesspasant-${VERSION}"

# Copy PKGBUILD into output
cp "$SCRIPT_DIR/PKGBUILD" "$OUTPUT_DIR/PKGBUILD"

# 7. Generate Pacman Repository Database ($OUTPUT_DIR/repo/x86_64)
REPO_DIR="$OUTPUT_DIR/repo/x86_64"
mkdir -p "$REPO_DIR"
cp "$PKG_FILE" "$REPO_DIR/"

if command -v repo-add >/dev/null 2>&1; then
    echo "==> [arch] Generating Pacman repository index database in $REPO_DIR..."
    cd "$REPO_DIR"
    repo-add chesspasant.db.tar.zst "$(basename "$PKG_FILE")"
else
    echo "⚠️  [arch] 'repo-add' not installed. Skipping local pacman repo database generation."
fi

# 8. Create 1-command automated installer script ($OUTPUT_DIR/repo/setup-repo.sh)
cat << 'SETUP_EOF' > "$OUTPUT_DIR/repo/setup-repo.sh"
#!/usr/bin/env bash
# ==============================================================================
# ChessPasant Official Arch Linux Repository Automated Setup
# Usage: curl -sSL https://chess.yogeshmallik.in/repo/setup-repo.sh | sudo bash
# ==============================================================================
set -euo pipefail

REPO_CONF="/etc/pacman.conf"
REPO_NAME="chesspasant"
REPO_URL="https://chess.yogeshmallik.in/repo/\$arch"

if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run this script with root privileges (sudo):"
  echo "  curl -sSL https://chess.yogeshmallik.in/repo/setup-repo.sh | sudo bash"
  exit 1
fi

echo "=================================================================="
echo "  ♟ Setting up ChessPasant Arch Linux Repository"
echo "=================================================================="

if grep -q "^\[${REPO_NAME}\]" "$REPO_CONF"; then
  echo "ℹ️  Updating [${REPO_NAME}] configuration in ${REPO_CONF}..."
  sed -i -e '/^\[chesspasant\]/,/^\[/ s/^SigLevel = .*/SigLevel = Optional DatabaseOptional/' "$REPO_CONF"
else
  echo "==> Adding [${REPO_NAME}] repository to ${REPO_CONF}..."
  cat << CONF_EOF >> "$REPO_CONF"

# ChessPasant Official Repository
[${REPO_NAME}]
SigLevel = Optional DatabaseOptional
Server = ${REPO_URL}
CONF_EOF
  echo "✅ Added [${REPO_NAME}] repository to ${REPO_CONF}."
fi

echo "==> Cleaning any stale or corrupted cache..."
rm -f /var/lib/pacman/sync/chesspasant.* /var/cache/pacman/pkg/chesspasant* 2>/dev/null || true

echo "==> Synchronizing repository and installing ChessPasant..."
pacman -Syy --noconfirm "${REPO_NAME}"

echo "=================================================================="
echo "🎉 ChessPasant installed successfully!"
echo "   Launch it by typing: chesspasant"
echo "   Future updates will arrive automatically via: sudo pacman -Syu"
echo "=================================================================="
SETUP_EOF
chmod +x "$OUTPUT_DIR/repo/setup-repo.sh"

echo "✅ [arch] Arch Linux packages & repository generated successfully:"
ls -lh "$OUTPUT_DIR"
ls -lh "$REPO_DIR"
