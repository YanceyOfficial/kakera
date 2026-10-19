#!/bin/zsh
# Captures the README / website screenshots: boots a simulator, pins a clean status bar, and runs
# KakeraUITests (ScreenshotTests), which plants the demo deck and saves <name>.png and <name>-dark.png.
#   scripts/screenshots.sh [simulator id]       → screenshots/
# Then the website's copies: (cd website && bun run shots ../screenshots)
set -euo pipefail
cd "$(dirname "$0")/.."
SIM="${1:-$(xcrun simctl list devices available | grep -m1 'iPhone 18 Pro (' | grep -oE '[0-9A-F-]{36}')}"
OUT="$PWD/screenshots"
mkdir -p "$OUT"

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b >/dev/null
# A fresh install, so the demo deck lands in an empty store.
xcrun simctl uninstall "$SIM" app.yancey.kakera 2>/dev/null || true
xcrun simctl status_bar "$SIM" override --time "9:41" --dataNetwork wifi --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

TEST_RUNNER_SHOTS_DIR="$OUT" xcodebuild test -workspace kakera.xcworkspace -scheme Kakera \
  -destination "id=$SIM" -only-testing:KakeraUITests/ScreenshotTests -quiet
xcrun simctl status_bar "$SIM" clear
ls "$OUT"
