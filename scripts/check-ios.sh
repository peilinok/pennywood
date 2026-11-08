#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -eq 0 ]]; then
  PENNYWOOD_DEVICE_KINDS=(iPhone iPad)
elif [[ $# -eq 1 && ( "$1" == iPhone || "$1" == iPad ) ]]; then
  PENNYWOOD_DEVICE_KINDS=("$1")
else
  printf '%s\n' 'Usage: ./scripts/check-ios.sh [iPhone|iPad]' >&2
  exit 64
fi
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
printf '%s\n' 'Checking locked CocoaPods metadata before native builds.'
"$PENNYWOOD_FLUTTER" build ios --simulator --debug --no-pub --config-only --target lib/main.dart
git diff --exit-code -- pubspec.lock ios/Podfile.lock
pod install --deployment --project-directory=ios
printf '%s\n' 'Building the production simulator entry.'
"$PENNYWOOD_FLUTTER" build ios --simulator --debug --no-pub --target lib/main.dart

# Choose only an available runtime/device type from the selected Xcode inventory.
# Every tested simulator is created here; never reset an existing simulator or device.
for PENNYWOOD_KIND in "${PENNYWOOD_DEVICE_KINDS[@]}"; do
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
  printf 'Booting the disposable %s simulator.\n' "$PENNYWOOD_KIND"
  xcrun simctl boot "$PENNYWOOD_SIMULATOR"
  xcrun simctl bootstatus "$PENNYWOOD_SIMULATOR" -b
  printf 'Running native optical tests on %s.\n' "$PENNYWOOD_KIND"
  "$PENNYWOOD_FLUTTER" build ios --simulator --debug --no-pub --config-only --target lib/main.dart
  xcodebuild test -quiet -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug \
    -destination "id=$PENNYWOOD_SIMULATOR" -parallel-testing-enabled NO \
    -derivedDataPath "$PENNYWOOD_IOS_EVIDENCE/$PENNYWOOD_KIND/NativeDerived" \
    -resultBundlePath "$PENNYWOOD_IOS_EVIDENCE/$PENNYWOOD_KIND/NativeTests.xcresult" \
    -only-testing:RunnerTests CODE_SIGNING_ALLOWED=NO
  for PENNYWOOD_TARGET in family_release_test family_release_restart_test; do
    printf 'Building %s on %s.\n' "$PENNYWOOD_TARGET" "$PENNYWOOD_KIND"
    "$PENNYWOOD_FLUTTER" build ios --simulator --debug --no-pub --target "integration_test/$PENNYWOOD_TARGET.dart"
    PENNYWOOD_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' build/ios/iphonesimulator/Runner.app/Info.plist)"
    printf 'Installing %s while retaining the simulator data.\n' "$PENNYWOOD_TARGET"
    xcrun simctl install "$PENNYWOOD_SIMULATOR" "$PWD/build/ios/iphonesimulator/Runner.app"
    printf 'Launching %s in a new process.\n' "$PENNYWOOD_TARGET"
    PENNYWOOD_LAUNCH="$(xcrun simctl launch "$PENNYWOOD_SIMULATOR" "$PENNYWOOD_BUNDLE_ID" \
      --enable-dart-profiling --disable-vm-service-publication --start-paused --enable-checked-mode --verify-entry-points)"
    PENNYWOOD_PROCESS_ID="${PENNYWOOD_LAUNCH##*: }"
    # Flutter's asynchronous live-log subscription can miss the startup VM URI.
    # Read retained logs for this PID, retaining authentication and a bounded wait.
    PENNYWOOD_SERVICE_URI="$(python3 scripts/ios_service_uri.py "$PENNYWOOD_SIMULATOR" "$PENNYWOOD_PROCESS_ID")"
    printf 'Running %s assertions on %s.\n' "$PENNYWOOD_TARGET" "$PENNYWOOD_KIND"
    "$PENNYWOOD_FLUTTER" drive --no-pub --debug --keep-app-running --no-uninstall-first -d "$PENNYWOOD_SIMULATOR" \
      --use-existing-app="$PENNYWOOD_SERVICE_URI" --driver test_driver/integration_test.dart --target "integration_test/$PENNYWOOD_TARGET.dart"
    # Keep storage; the companion must read the previous process's database.
    xcrun simctl terminate "$PENNYWOOD_SIMULATOR" "$PENNYWOOD_BUNDLE_ID"
    printf 'Passed %s on %s.\n' "$PENNYWOOD_TARGET" "$PENNYWOOD_KIND"
  done
  cleanup
  PENNYWOOD_SIMULATOR=''
done
git diff --exit-code -- pubspec.lock ios/Podfile.lock
