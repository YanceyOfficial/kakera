#!/bin/zsh
# Captures screenshots by driving KakeraUITests (ScreenshotTests) on a simulator — it plants the demo
# deck, pins a clean status bar and saves <name>.png and <name>-dark.png per screen.
#
#   scripts/screenshots.sh [simulator id]            → screenshots/              the README / website set
#   scripts/screenshots.sh --appstore [iphone|ipad|duo]…
#                                                    → screenshots/appstore/<device>/   the App Store sets
#
# App Store Connect wants iPhone 6.3" (1206×2622), iPad 13" (2064×2752) and iPhone Duo (1398×2034).
# Each set runs on a simulator named "Kakera <Device>" of that device type, created on first use, so
# nothing else's simulators are touched. The App Store sets stay out of the repository.
# Then the website's copies: (cd website && bun run shots ../screenshots)
set -euo pipefail
# The physical path: the simulator sees the host file system case-sensitively, so a folder reached
# through a differently-cased spelling (~/code for ~/Code) does not exist to the test runner.
cd "$(dirname "$0")/.." && cd "$(pwd -P)"

typeset -A DEVICE_NAME=( iphone "Kakera iPhone" ipad "Kakera iPad" duo "Kakera Duo" )
typeset -A DEVICE_TYPE=(
  iphone com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro
  ipad   com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB
  duo    com.apple.CoreSimulator.SimDeviceType.iPhone-Duo
)

# The simulator for a device set: the one named for it, created (on the newest runtime) if absent.
simulator_for() {
  local name="$DEVICE_NAME[$1]"
  local id
  id=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for device in devices:
        if device["name"] == name:
            print(device["udid"]); sys.exit()
' "$name")
  if [[ -z "$id" ]]; then
    echo "creating simulator “$name” ($DEVICE_TYPE[$1])" >&2
    id=$(xcrun simctl create "$name" "$DEVICE_TYPE[$1]")
  fi
  echo "$id"
}

# Runs the capture on one simulator into one folder.
capture() {
  local sim="$1" out="$2"
  mkdir -p "$out"
  xcrun simctl boot "$sim" 2>/dev/null || true
  xcrun simctl bootstatus "$sim" -b >/dev/null
  # A fresh install, so the demo deck lands in an empty store.
  xcrun simctl uninstall "$sim" app.yancey.kakera 2>/dev/null || true
  xcrun simctl status_bar "$sim" override --time "9:41" --dataNetwork wifi --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

  TEST_RUNNER_SHOTS_DIR="$out" xcodebuild test -workspace kakera.xcworkspace -scheme Kakera \
    -destination "id=$sim" -only-testing:KakeraUITests/ScreenshotTests -quiet
  xcrun simctl status_bar "$sim" clear
  echo "→ $out"
  ls "$out"
}

if [[ "${1:-}" == "--appstore" ]]; then
  shift
  sets=("$@"); (( $#sets )) || sets=(iphone ipad duo)
  for device in "${sets[@]}"; do
    [[ -n "${DEVICE_NAME[$device]:-}" ]] || { echo "unknown device “$device” (iphone, ipad, duo)" >&2; exit 2 }
    capture "$(simulator_for "$device")" "$PWD/screenshots/appstore/$device"
  done
else
  capture "${1:-$(simulator_for iphone)}" "$PWD/screenshots"
fi
