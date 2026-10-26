#!/usr/bin/env bash
# Sends a deep link to a running Android emulator or iOS Simulator, as if the user tapped it.
#
# Usage:
#   scripts/test_deeplink.sh android "tdeeplink://product/42?ref=email"
#   scripts/test_deeplink.sh ios     "tdeeplink://profile/john"
#   scripts/test_deeplink.sh both    "https://example.com/product/7"
#
# The app must be installed first (flutter run). It can be closed (cold start) or open (warm start).

# Stop on errors and on unset variables.
set -euo pipefail

# Android package name / iOS bundle id (both are the same here).
APP_ID="com.example.tdeeplink"

# First argument: which platform.
PLATFORM="${1:-}"
# Second argument: the link (defaults to a product link).
URL="${2:-tdeeplink://product/42?ref=script}"

# Use adb from PATH, or fall back to the default Android SDK location on macOS.
ADB="$(command -v adb || echo "$HOME/Library/Android/sdk/platform-tools/adb")"

send_android() {
  echo "Android -> $URL"
  # am start = start an activity; -W = wait until it launched;
  # -a VIEW = same action as a tapped link; -d = the link; last arg = only our app may receive it.
  # Remove "$APP_ID" at the end to let Android pick the app itself (closer to a real tap).
  "$ADB" shell am start -W -a android.intent.action.VIEW -d "'$URL'" "$APP_ID"
}

send_ios() {
  echo "iOS -> $URL"
  # simctl openurl = ask the Simulator to open the link, exactly like tapping it.
  # "booted" = the booted Simulator; with several booted, set IOS_SIM to a UDID (xcrun simctl list devices booted).
  xcrun simctl openurl "${IOS_SIM:-booted}" "$URL"
}

# Pick what to run based on the first argument.
case "$PLATFORM" in
  android) send_android ;;
  ios) send_ios ;;
  both) send_android; send_ios ;;
  *) echo "Usage: $0 android|ios|both <url>" >&2; exit 1 ;;
esac
