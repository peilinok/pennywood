#!/usr/bin/env python3
"""Check tracked platform roots and direct pure-Dart domain dependencies."""
import json
from pathlib import Path
import posixpath
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
UNSUPPORTED = {'android', 'web', 'macos', 'windows', 'linux'}
DOMAIN_SDK = {'dart:core', 'dart:math', 'dart:collection', 'dart:convert', 'dart:typed_data', 'dart:async'}


def main():
    names = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    issues = []
    for name in filter(None, names):
        if name.split('/')[0] in UNSUPPORTED:
            issues.append({'rule': 'unsupported-platform-target', 'file': name})
        if not name.startswith('lib/domain/') or not name.endswith('.dart'):
            continue
        text = (ROOT / name).read_text()
        for directive in re.finditer(r'^\s*(?:import|export|part)\b[^;]*;', text, re.MULTILINE):
            for uri in re.findall(r'''["']([^"']+)["']''', directive.group()):
                resolved = posixpath.normpath(posixpath.join(posixpath.dirname(name), uri))
                if uri in DOMAIN_SDK or ':' not in uri and resolved.startswith('lib/domain/'):
                    continue
                issues.append({'rule': 'domain-dependency-boundary', 'file': name,
                               'line': text.count('\n', 0, directive.start()) + 1})
    print(json.dumps({'issue_count': len(issues), 'issues': issues}, indent=2))
    return 1 if issues else 0


if __name__ == '__main__':
    raise SystemExit(main())
