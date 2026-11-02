#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
PENNYWOOD_FLUTTER="${PENNYWOOD_FLUTTER:-$(command -v flutter || true)}"
if [[ -z "$PENNYWOOD_FLUTTER" ]]; then
  PENNYWOOD_FLUTTER="$HOME/development/flutter/bin/flutter"
fi
if [[ "$(uname -s)" != Darwin || ! -x "$PENNYWOOD_FLUTTER" ]]; then
  printf '%s\n' 'iOS checks require macOS, Xcode, Flutter, and an installed iOS simulator runtime.' >&2
  exit 1
fi
PENNYWOOD_SIMULATOR=''
cleanup() {
  if [[ -n "$PENNYWOOD_SIMULATOR" ]]; then
    xcrun simctl shutdown "$PENNYWOOD_SIMULATOR" >/dev/null 2>&1 || true
    xcrun simctl delete "$PENNYWOOD_SIMULATOR" >/dev/null 2>&1 || true
  fi
}
finish() {
  PENNYWOOD_CHECK_STATUS=$?
  cleanup
  # Leave generated local configuration pointing at production, including after a failed test.
  if ! "$PENNYWOOD_FLUTTER" build ios --simulator --debug --no-pub --config-only --target lib/main.dart; then
    PENNYWOOD_CHECK_STATUS=1
  fi
  exit "$PENNYWOOD_CHECK_STATUS"
}
trap finish EXIT
mkdir -p work
PENNYWOOD_IOS_EVIDENCE="$(mktemp -d "$PWD/work/ios-check.XXXXXX")"
"$PENNYWOOD_FLUTTER" pub get --enforce-lockfile
"$PENNYWOOD_FLUTTER" build ios --simulator --debug --no-pub --target lib/main.dart

# Choose only an available runtime/device type from the selected Xcode inventory.
# Every tested simulator is created here; never reset an existing simulator or device.
for PENNYWOOD_KIND in iPhone iPad; do
  export PENNYWOOD_EVIDENCE_DIR="$PENNYWOOD_IOS_EVIDENCE/$PENNYWOOD_KIND"
  PENNYWOOD_SIM_CONFIG="$(xcrun simctl list --json | python3 -c '
import json, os, sys
inventory = json.load(sys.stdin)
wanted = os.environ.get("PENNYWOOD_IOS_RUNTIME")
runtimes = [r for r in inventory["runtimes"]
            if r.get("isAvailable") and ".iOS-" in r["identifier"]
            and (not wanted or r["identifier"] == wanted)]
if not runtimes:
    raise SystemExit("No compatible installed iOS runtime found")
runtime = max(runtimes, key=lambda r: tuple(int(p) for p in r["version"].split(".")))
devices = [d for d in inventory["devicetypes"] if d["name"].startswith(sys.argv[1])
           and d.get("minRuntimeVersion", 0) <= int(runtime["version"].split(".")[0]) * 65536
           + int(runtime["version"].split(".")[1]) * 256 <= d.get("maxRuntimeVersion", 2**32)]
if not devices:
    raise SystemExit("No compatible iPhone/iPad simulator type found")
device = devices[-1]
print(device["identifier"])
print(runtime["identifier"])
' "$PENNYWOOD_KIND")"
  PENNYWOOD_DEVICE_TYPE="${PENNYWOOD_SIM_CONFIG%%$'\n'*}"
  PENNYWOOD_RUNTIME="${PENNYWOOD_SIM_CONFIG##*$'\n'}"
  PENNYWOOD_SIMULATOR="$(xcrun simctl create "Pennywood-CI-$PENNYWOOD_KIND" "$PENNYWOOD_DEVICE_TYPE" "$PENNYWOOD_RUNTIME")"
  xcrun simctl boot "$PENNYWOOD_SIMULATOR"
  xcrun simctl bootstatus "$PENNYWOOD_SIMULATOR" -b
  for PENNYWOOD_TARGET in family_release_test family_release_restart_test; do
    "$PENNYWOOD_FLUTTER" drive --no-pub --debug -d "$PENNYWOOD_SIMULATOR" \
      --driver test_driver/integration_test.dart --target "integration_test/$PENNYWOOD_TARGET.dart"
  done
  cleanup
  PENNYWOOD_SIMULATOR=''
done
git diff --exit-code -- pubspec.lock ios/Podfile.lock
