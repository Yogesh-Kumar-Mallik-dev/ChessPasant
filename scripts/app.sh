#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$SCRIPT_DIR/apps/app"

# Ensure flutter is in PATH
if ! command -v flutter >/dev/null 2>&1; then
  if [ -d "$HOME/.local/share/flutter/bin" ]; then
    export PATH="$HOME/.local/share/flutter/bin:$PATH"
  fi
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ Flutter SDK not found in PATH or ~/.local/share/flutter/bin"
  exit 1
fi

SUBCOMMAND="${1:-run}"
shift || true

cd "$APP_DIR"

case "$SUBCOMMAND" in
  run)
    echo "==> [app] Running Flutter native desktop app..."
    flutter run -d linux "$@"
    ;;
  build)
    echo "==> [app] Building Flutter native Linux release bundle..."
    flutter build linux --release "$@"
    ;;
  apk)
    echo "==> [app] Building Flutter Android release APK..."
    flutter build apk --release "$@"
    ;;
  check|analyze)
    echo "==> [app] Running flutter analyze..."
    flutter analyze "$@"
    ;;
  test)
    echo "==> [app] Running flutter test..."
    flutter test "$@"
    ;;
  *)
    echo "Usage: ./script.sh app [run|build|apk|check|test]"
    exit 1
    ;;
esac
