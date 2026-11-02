#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
PENNYWOOD_FLUTTER="${PENNYWOOD_FLUTTER:-$(command -v flutter || true)}"
if [[ -z "$PENNYWOOD_FLUTTER" ]]; then
  PENNYWOOD_FLUTTER="$HOME/development/flutter/bin/flutter"
fi
if [[ ! -x "$PENNYWOOD_FLUTTER" ]]; then
  printf '%s\n' 'Flutter was not found. Set PENNYWOOD_FLUTTER to the Flutter executable.' >&2
  exit 1
fi
PENNYWOOD_DART="$(dirname "$PENNYWOOD_FLUTTER")/dart"
"$PENNYWOOD_FLUTTER" pub get --enforce-lockfile
"$PENNYWOOD_DART" format --output=none --set-exit-if-changed lib test integration_test test_driver
"$PENNYWOOD_FLUTTER" analyze --no-pub --fatal-infos --fatal-warnings
"$PENNYWOOD_FLUTTER" test --no-pub --reporter expanded
python3 scripts/test_publication.py
python3 scripts/test_repository_policy.py
python3 scripts/test_ios_service_uri.py
python3 scripts/check-repository.py
python3 scripts/check-publication.py
python3 scripts/check-publication.py --history
node reference/verify-finance.cjs
node reference/generate-finance-cases.cjs
git diff --exit-code -- reference/finance-golden-cases.json
python3 prototype/wishboard/build.py
python3 prototype/interaction-lab/build.py
python3 reference/prototype-source/build.py
git diff --exit-code -- pubspec.lock ios/Podfile.lock
