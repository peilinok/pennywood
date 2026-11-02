#!/bin/zsh
set -eu
cd "${0:A:h:h}"
PENNYWOOD_FLUTTER="${PENNYWOOD_FLUTTER:-$(command -v flutter || true)}"
if [[ -z "$PENNYWOOD_FLUTTER" ]]; then
  PENNYWOOD_FLUTTER="$HOME/development/flutter/bin/flutter"
fi
PENNYWOOD_DART="${PENNYWOOD_FLUTTER:h}/dart"
"$PENNYWOOD_FLUTTER" pub get --enforce-lockfile
"$PENNYWOOD_DART" format --output=none --set-exit-if-changed lib test integration_test test_driver
"$PENNYWOOD_FLUTTER" analyze --no-pub
"$PENNYWOOD_FLUTTER" test --no-pub --reporter expanded
