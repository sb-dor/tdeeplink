#!/usr/bin/env bash
# Sends a deep link to a running Android emulator or iOS Simulator, as if the user tapped it.
#
# Usage:
#   scripts/test_deeplink.sh android "tdeeplink://product/42?ref=email"
#   scripts/test_deeplink.sh ios     "tdeeplink://profile/john"
#   scripts/test_deeplink.sh both    "https://example.com/product/7"
#   scripts/test_deeplink.sh android "tdeeplink://product/42" cold   # close the app first
#   IOS_SIM=<udid> scripts/test_deeplink.sh ios "tdeeplink://product/42"   # pick a specific Simulator
#
# iOS: without IOS_SIM, the first booted Simulator that has the app installed is used.
# List booted Simulators and their UDIDs with: xcrun simctl list devices booted
#
# The app must be installed first (flutter run). It can be closed (cold start) or open (warm start).
# Add "cold" as the 3rd argument to force a cold start: needed when the app only reads
# PlatformDispatcher.defaultRouteName, which holds just the link that launched the app.

# Stop on errors and on unset variables.
set -euo pipefail

# Android package name / iOS bundle id (both are the same here).
APP_ID="com.example.tdeeplink"

# First argument: which platform.
PLATFORM="${1:-}"
# Second argument: the link (defaults to a product link).
URL="${2:-tdeeplink://product/42?ref=script}"
# Third argument: "cold" = stop the app before sending the link.
MODE="${3:-}"

# Use adb from PATH, or fall back to the default Android SDK location on macOS.
ADB="$(command -v adb || echo "$HOME/Library/Android/sdk/platform-tools/adb")"

send_android() {
  echo "Android -> $URL"
  # force-stop = kill the app, so the link launches it fresh (cold start).
  if [ "$MODE" = "cold" ]; then "$ADB" shell am force-stop "$APP_ID"; fi
  # am start = start an activity; -W = wait until it launched;
  # -a VIEW = same action as a tapped link; -d = the link; last arg = only our app may receive it.
  # Remove "$APP_ID" at the end to let Android pick the app itself (closer to a real tap).
  "$ADB" shell am start -W -a android.intent.action.VIEW -d "'$URL'" "$APP_ID"
}

send_ios() {
  # Which Simulator: IOS_SIM if set, otherwise the first booted one that has the app installed.
  # (Plain "booted" may pick a Simulator without the app -> LSApplicationWorkspaceErrorDomain error 115.)
  local sim="${IOS_SIM:-}"
  if [ -z "$sim" ]; then
    # Go through every booted Simulator's UDID.
    for udid in $(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}'); do
      # get_app_container succeeds only if the app is installed there.
      if xcrun simctl get_app_container "$udid" "$APP_ID" >/dev/null 2>&1; then sim="$udid"; break; fi
    done
  fi
  # None found: the app isn't installed on any booted Simulator.
  if [ -z "$sim" ]; then
    echo "No booted Simulator has $APP_ID installed. Run: flutter run -d <simulator>" >&2
    exit 1
  fi
  echo "iOS ($sim) -> $URL"
  # terminate = kill the app, so the link launches it fresh (cold start). Fails harmlessly if not running.
  if [ "$MODE" = "cold" ]; then xcrun simctl terminate "$sim" "$APP_ID" 2>/dev/null || true; fi
  # simctl openurl = ask the Simulator to open the link, exactly like tapping it.
  xcrun simctl openurl "$sim" "$URL"
}

# Pick what to run based on the first argument.
case "$PLATFORM" in
  android) send_android ;;
  ios) send_ios ;;
  both) send_android; send_ios ;;
  *) echo "Usage: $0 android|ios|both <url> [cold]" >&2; exit 1 ;;
esac
