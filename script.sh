#!/usr/bin/env bash
# ==============================================================================
# Universal Project Lifecycle Orchestrator (POSIX Entrypoint)
# Conforming to engineering-standards / SCRIPT_ORCHESTRATION_GUIDE.md
# Usage: ./script.sh [dev|build|check|test|deps|envi|uenvi|flush]
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND="${1:-dev}"
shift || true

function show_help() {
  echo "=================================================================="
  echo "  ♟ ChessPasant Platform Lifecycle Orchestrator"
  echo "=================================================================="
  echo "Usage: ./script.sh <command> [args...]"
  echo ""
  echo "Available commands:"
  echo "  dev      Start local infrastructure and launch servers"
  echo "  build    Build Go backend binary and SvelteKit frontend bundle"
  echo "  check    Run typecheckers, linters, and static analysis"
  echo "  test     Run chess engine unit tests and integration tests"
  echo "  deps     Install Go and npm dependencies"
  echo "  envi     Initialize local environment and start Docker services"
  echo "  uenvi    Tear down local Docker containers"
  echo "  desktop  Launch ChessPasant Tauri desktop application in dev mode"
  echo "  desktop-build Build ChessPasant Tauri desktop native release binary"
  echo "  desktop-arch  Package ChessPasant for Arch Linux (.pkg.tar.zst & .tar.gz)"
  echo "  desktop-deploy-arch Deploy Arch Linux repository to production VPS"
  echo "  mobile   Manage, check, and build ChessPasant Tauri mobile (Android/iOS)"
  echo "  app      Run, build, or test the native Flutter cross-platform app"
  echo "  engine   Launch standalone Stockfish 19 engine microservice (port 8081)"
  echo "  flush    Flush database (MongoDB) and Redis caches"
  echo "  help     Display this help message"
  echo "=================================================================="
}

case "$COMMAND" in
  dev)
    if [ -f "$SCRIPT_DIR/scripts/dev.sh" ]; then
      exec "$SCRIPT_DIR/scripts/dev.sh" "$@"
    else
      echo "scripts/dev.sh not found"
      exit 1
    fi
    ;;
  build)
    if [ -f "$SCRIPT_DIR/scripts/build.sh" ]; then
      exec "$SCRIPT_DIR/scripts/build.sh" "$@"
    else
      echo "scripts/build.sh not found"
      exit 1
    fi
    ;;
  check)
    if [ -f "$SCRIPT_DIR/scripts/check.sh" ]; then
      exec "$SCRIPT_DIR/scripts/check.sh" "$@"
    else
      echo "scripts/check.sh not found"
      exit 1
    fi
    ;;
  test)
    if [ -f "$SCRIPT_DIR/scripts/test.sh" ]; then
      exec "$SCRIPT_DIR/scripts/test.sh" "$@"
    else
      echo "scripts/test.sh not found"
      exit 1
    fi
    ;;
  deps)
    if [ -f "$SCRIPT_DIR/scripts/deps.sh" ]; then
      exec "$SCRIPT_DIR/scripts/deps.sh" "$@"
    else
      echo "scripts/deps.sh not found"
      exit 1
    fi
    ;;
  envi)
    if [ -f "$SCRIPT_DIR/scripts/envi.sh" ]; then
      exec "$SCRIPT_DIR/scripts/envi.sh" "$@"
    else
      echo "scripts/envi.sh not found"
      exit 1
    fi
    ;;
  uenvi)
    if [ -f "$SCRIPT_DIR/scripts/uenvi.sh" ]; then
      exec "$SCRIPT_DIR/scripts/uenvi.sh" "$@"
    else
      echo "scripts/uenvi.sh not found"
      exit 1
    fi
    ;;
  flush|flush-db|flush_db)
    if [ -f "$SCRIPT_DIR/scripts/flush_db.sh" ]; then
      exec "$SCRIPT_DIR/scripts/flush_db.sh" "$@"
    else
      echo "scripts/flush_db.sh not found"
      exit 1
    fi
    ;;
  desktop)
    if [ -f "$SCRIPT_DIR/scripts/desktop.sh" ]; then
      exec "$SCRIPT_DIR/scripts/desktop.sh" dev "$@"
    else
      echo "scripts/desktop.sh not found"
      exit 1
    fi
    ;;
  desktop-build)
    if [ -f "$SCRIPT_DIR/scripts/desktop.sh" ]; then
      exec "$SCRIPT_DIR/scripts/desktop.sh" build "$@"
    else
      echo "scripts/desktop.sh not found"
      exit 1
    fi
    ;;
  desktop-arch)
    if [ -f "$SCRIPT_DIR/scripts/desktop.sh" ]; then
      exec "$SCRIPT_DIR/scripts/desktop.sh" arch "$@"
    else
      echo "scripts/desktop.sh not found"
      exit 1
    fi
    ;;
  desktop-deploy-arch|deploy-arch)
    if [ -f "$SCRIPT_DIR/scripts/desktop.sh" ]; then
      exec "$SCRIPT_DIR/scripts/desktop.sh" deploy-arch "$@"
    else
      echo "scripts/desktop.sh not found"
      exit 1
    fi
    ;;
  mobile)
    if [ -f "$SCRIPT_DIR/scripts/mobile.sh" ]; then
      exec "$SCRIPT_DIR/scripts/mobile.sh" "$@"
    else
      echo "scripts/mobile.sh not found"
      exit 1
    fi
    ;;
  app)
    if [ -f "$SCRIPT_DIR/scripts/app.sh" ]; then
      exec "$SCRIPT_DIR/scripts/app.sh" "$@"
    else
      echo "scripts/app.sh not found"
      exit 1
    fi
    ;;
  engine)
    echo "==> [engine] Launching standalone Stockfish 19 engine microservice on port 8081..."
    cd "$SCRIPT_DIR/apps/server"
    exec go run cmd/engine-service/main.go "$@"
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    echo "Unknown command: $COMMAND"
    show_help
    exit 1
    ;;
esac
