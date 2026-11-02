#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
PENNYWOOD_GITLEAKS="${PENNYWOOD_GITLEAKS:-$(command -v gitleaks || true)}"
if [[ ! -x "$PENNYWOOD_GITLEAKS" ]]; then
  printf '%s\n' 'gitleaks 8.30.1 is required. Set PENNYWOOD_GITLEAKS to its executable.' >&2
  exit 1
fi
if [[ "$("$PENNYWOOD_GITLEAKS" version)" != '8.30.1' ]]; then
  printf '%s\n' 'Use the audited gitleaks 8.30.1 release.' >&2
  exit 1
fi

# No custom rules, baseline, environment configuration, or inherited ignore file.
unset GITLEAKS_CONFIG GITLEAKS_CONFIG_TOML
PENNYWOOD_SECRET_TEMP="$(mktemp -d)"
trap 'rm -rf "$PENNYWOOD_SECRET_TEMP"' EXIT
git ls-files -z | python3 -c '
from pathlib import Path
import shutil, sys
destination = Path(sys.argv[1])
for name in filter(None, sys.stdin.buffer.read().decode().split("\0")):
    source = Path(name)
    if source.is_symlink() or not source.is_file():
        raise SystemExit("Secret scan requires regular tracked files")
    target = destination / source
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
' "$PENNYWOOD_SECRET_TEMP/tree"
"$PENNYWOOD_GITLEAKS" git . --log-opts=--all --redact --no-banner --ignore-gitleaks-allow \
  --gitleaks-ignore-path "$PENNYWOOD_SECRET_TEMP/no-ignore"
"$PENNYWOOD_GITLEAKS" dir "$PENNYWOOD_SECRET_TEMP/tree" --redact --no-banner --ignore-gitleaks-allow \
  --gitleaks-ignore-path "$PENNYWOOD_SECRET_TEMP/no-ignore"
