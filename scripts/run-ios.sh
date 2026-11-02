#!/bin/zsh
set -eu
cd "${0:A:h:h}"
PENNYWOOD_FLUTTER="${PENNYWOOD_FLUTTER:-$(command -v flutter || true)}"
if [[ -z "$PENNYWOOD_FLUTTER" && -x "$HOME/development/flutter/bin/flutter" ]]; then
  PENNYWOOD_FLUTTER="$HOME/development/flutter/bin/flutter"
fi
if [[ ! -x "$PENNYWOOD_FLUTTER" ]]; then
  print -u2 'Flutter 3.35.7 was not found. Set PENNYWOOD_FLUTTER to the Flutter executable.'
  exit 1
fi
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-16.1.0.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-16.1.0.app/Contents/Developer
fi
if [[ $# -eq 0 ]]; then
  "$PENNYWOOD_FLUTTER" devices
  print 'Choose an iPhone or iPad: ./scripts/run-ios.sh SIMULATOR_OR_DEVICE_ID'
  exit 0
fi
"$PENNYWOOD_FLUTTER" run -d "$1"
