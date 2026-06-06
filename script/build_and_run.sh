#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Alan Beckers Stickfigures"
BUNDLE_ID="com.skittlq.alanbeckersstickfigures.unofficial"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

stop_running_app() {
  pkill -f "$APP_BINARY" >/dev/null 2>&1 || true
  pkill -f "AlansStickfigures.jar" >/dev/null 2>&1 || true
}

build_app() {
  "$ROOT_DIR/script/build_macos_app.sh" >/dev/null
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

verify_app() {
  sleep 3
  if ! pgrep -f "$APP_BINARY" >/dev/null; then
    echo "$APP_NAME did not stay running." >&2
    exit 1
  fi
  if ! pgrep -f "AlansStickfigures.jar" >/dev/null; then
    echo "The Java stickfigures process did not stay running." >&2
    exit 1
  fi
}

case "$MODE" in
  run)
    stop_running_app
    build_app
    open_app
    ;;
  --debug|debug)
    stop_running_app
    build_app
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    stop_running_app
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    stop_running_app
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    stop_running_app
    build_app
    open_app
    verify_app
    ;;
  --package|package)
    "$ROOT_DIR/script/package_macos.sh"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--package]" >&2
    exit 2
    ;;
esac
