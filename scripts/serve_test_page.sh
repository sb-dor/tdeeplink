#!/usr/bin/env bash
# Serves hosting/public/index.html (a page of tappable test links) and opens it in the
# browser of every connected Android device/emulator and booted iOS Simulator.
# Then tap a link on the device, exactly like a real user.
#
# Usage:
#   scripts/serve_test_page.sh          # port 8000
#   scripts/serve_test_page.sh 9000     # another port
#
# Android: Chrome opens the page via adb reverse (works for emulators and USB phones).
# iOS Simulator: Safari opens it directly (the Simulator shares the Mac's localhost).
#   With several Simulators booted, set IOS_SIM=<udid> to pick one.
#
# Stop with Ctrl+C.

# Stop on errors and on unset variables.
set -euo pipefail

# Port for the local web server.
PORT="${1:-8000}"
# The page URL as seen from the devices.
PAGE_URL="http://localhost:$PORT/"

# Folder that contains index.html (relative to this script, so it works from any directory).
PAGE_DIR="$(cd "$(dirname "$0")/../hosting/public" && pwd)"

# Use adb from PATH, or fall back to the default Android SDK location on macOS.
ADB="$(command -v adb || echo "$HOME/Library/Android/sdk/platform-tools/adb")"

open_on_devices() {
  # Android: only if adb exists and a device/emulator is connected.
  if [ -x "$ADB" ] && "$ADB" get-state >/dev/null 2>&1; then
    # adb reverse = the device's localhost:PORT now points at this Mac's localhost:PORT.
    "$ADB" reverse "tcp:$PORT" "tcp:$PORT" >/dev/null
    # Open the page in the device's default browser.
    "$ADB" shell am start -a android.intent.action.VIEW -d "$PAGE_URL" >/dev/null
    echo "Opened on Android"
  fi

  # iOS: IOS_SIM if set, otherwise the first booted Simulator (if any).
  local sim="${IOS_SIM:-$(xcrun simctl list devices booted 2>/dev/null | grep -oE '[0-9A-F-]{36}' | head -1)}"
  if [ -n "$sim" ]; then
    # Open the page in the Simulator's Safari.
    xcrun simctl openurl "$sim" "$PAGE_URL"
    echo "Opened on iOS Simulator $sim"
  fi
}

# Open the page on the devices once the server below is up.
( sleep 1; open_on_devices ) &

echo "Serving $PAGE_DIR at $PAGE_URL (Ctrl+C to stop)"
# Simple static web server from Python's standard library.
python3 -m http.server "$PORT" --directory "$PAGE_DIR"
