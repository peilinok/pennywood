#!/usr/bin/env python3
"""Check tracked files, staged blobs, and reachable history without echoing sensitive values."""
import argparse
import fnmatch
import json
import posixpath
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
HAN = re.compile(r'[\u3400-\u9fff\U00020000-\U0002fa1f]')
RULES = {
    'personal-absolute-path': re.compile(r'/(?:Users|home)/[A-Za-z][A-Za-z0-9._-]*(?:/|\b)'),
    'device-udid-pattern': re.compile(r'(?<![A-Za-z0-9])[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}(?![A-Za-z0-9])'),
    'hardcoded-signing-team': re.compile(r'(?m)^\s*DEVELOPMENT_TEAM\s*=\s*[A-Z0-9]{10}\s*;?\s*$'),
    'private-key': re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'),
    'github-token': re.compile(r'\b(?:gh[pousr]_[A-Za-z0-9_]{30,}|github_pat_[A-Za-z0-9_]{30,})\b'),
    'cloud-access-key': re.compile(r'\b(?:AKIA|ASIA)[0-9A-Z]{16}\b'),
    'url-embedded-password': re.compile(r'\b(?:https?|ssh)://[^\s/:@]+:[^\s/@]+@'),
}
EMAIL = re.compile(r'(?<![\w.+-])[\w.+-]+@[A-Za-z0-9.-]+\.(?:com|org|net|cn|io|me|dev|edu|test)\b')
UPSTREAM_EMAIL_FILE = 'ios/Specs/sqlite3.podspec.json'
BLOCKED_PARTS = {
    'work', 'outputs', 'build', 'Pods', '.symlinks', '.dart_tool', 'xcuserdata',
    'node_modules', '__pycache__', 'reference/verification',
}
BLOCKED_NAMES = [
    '.env', '.env.*', '*.local.xcconfig', '*.sqlite*', '*.db', '*.db-*', '*.pennywood',
    '*.ipa', '*.apk', '*.zip', '*.tgz', '*.tar.gz', '*.p12', '*.p8', '*.pem', '*.key',
    '*.mobileprovision', '*.provisionprofile', '*.keychain*', '*.log', '*.pyc',
    'Generated.xcconfig', 'flutter_export_environment.sh', 'selected-devices.json',
]
ROOT_FILES = {'.gitignore', '.metadata', 'AGENTS.md', 'README.md', 'analysis_options.yaml', 'pubspec.yaml', 'pubspec.lock'}
ROOT_DIRS = {'lib', 'test', 'integration_test', 'test_driver', 'scripts', 'ios', 'assets', 'design-system', 'docs', 'prototype', 'reference', 'evidence'}


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def trees(args):
    if args.history:
        commits = git('rev-list', '--all').decode().splitlines()
        if not commits:
            raise RuntimeError('No commits to inspect')
        for commit in commits:
            entries = {}
            for entry in git('ls-tree', '-rz', commit).split(b'\0'):
                if not entry:
                    continue
                meta, name = entry.split(b'\t', 1)
                mode, kind, oid = meta.decode().split()
                if kind != 'blob':
                    raise RuntimeError('Unchecked submodules are not allowed')
                entries[name.decode()] = (mode, oid)
            yield commit, entries
    else:
        entries = {}
        for entry in git('ls-files', '--stage', '-z').split(b'\0'):
            if not entry:
                continue
            meta, name = entry.split(b'\t', 1)
            mode, oid, stage = meta.decode().split()
            if stage != '0':
                raise RuntimeError('Unresolved index conflicts')
            entries[name.decode()] = (mode, oid)
        if not entries:
            raise RuntimeError('No tracked files; an empty scan cannot pass')
        yield 'staged' if args.staged else 'tracked-worktree', entries


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--staged', action='store_true', help='Inspect staged blobs instead of working files')
    group.add_argument('--history', action='store_true', help='Inspect all reachable commits and their identities')
    parser.add_argument('--private-needles', type=Path, help='Local-only exact private-string JSON list; never commit it')
    parser.add_argument('--report', type=Path, help='Write a JSON report without secret values')
    args = parser.parse_args()
    needles = json.loads(args.private_needles.read_text()) if args.private_needles else []
    if not isinstance(needles, list) or not all(isinstance(s, str) and s for s in needles):
        raise RuntimeError('Private needles must be a list of nonempty strings')
    issues = []
    blobs = {}
    checked = set()
    tree_count = 0

    def issue(rule, name, line=0):
        item = {'rule': rule, 'file': name, 'line': line}
        if item not in issues:
            issues.append(item)

    for tree, entries in trees(args):
        tree_count += 1
        texts = {}
        for name, (mode, oid) in entries.items():
            parts = Path(name).parts
            if not name.isascii():
                issue('public-path-must-be-ascii', name)
            if mode not in {'100644', '100755'}:
                issue('symlink-or-unknown-mode', name)
            if len(parts) == 1 and name not in ROOT_FILES or len(parts) > 1 and parts[0] not in ROOT_DIRS:
                issue('outside-public-root-allowlist', name)
            if any(p in BLOCKED_PARTS or p.endswith(('.app', '.framework', '.xcresult')) for p in parts):
                issue('private-or-generated-directory', name)
            if name.startswith('evidence/') and not name.startswith('evidence/public/'):
                issue('raw-acceptance-evidence', name)
            if name.startswith(('assets/reference/', 'reference/history/', 'reference/\u5386\u53f2\u6587\u6863/')):
                issue('unreviewed-reference-material', name)
            if any(fnmatch.fnmatch(parts[-1], pattern) for pattern in BLOCKED_NAMES):
                issue('prohibited-file-or-config', name)
            if args.staged or args.history:
                if oid not in blobs:
                    blobs[oid] = git('cat-file', 'blob', oid)
                data = blobs[oid]
            else:
                path = ROOT / name
                if path.is_symlink():
                    issue('worktree-symlink', name)
                    continue
                data = path.read_bytes()
            checked.add((name, oid))
            if len(data) > 5 * 1024 * 1024:
                issue('unreviewed-file-over-5mib', name)
            if data.startswith(b'\x89PNG\r\n\x1a\n'):
                offset = 8
                while offset < len(data):
                    size = int.from_bytes(data[offset:offset + 4], 'big')
                    kind = data[offset + 4:offset + 8]
                    if kind not in {b'IHDR', b'PLTE', b'IDAT', b'IEND', b'tRNS', b'gAMA', b'sRGB'}:
                        issue('unreviewed-png-metadata', name)
                    offset += size + 12
                continue
            try:
                text = data.decode('utf-8')
            except UnicodeDecodeError:
                issue('unreviewed-binary', name)
                continue
            if name.endswith('.md'):
                texts[name] = text
                if HAN.search(text):
                    issue('documentation-must-be-english', name)
            for rule, pattern in RULES.items():
                for match in pattern.finditer(text):
                    issue(rule, name, text.count('\n', 0, match.start()) + 1)
            for needle in needles:
                if needle in text:
                    issue('exact-private-needle', name, text.count('\n', 0, text.index(needle)) + 1)
            if name != UPSTREAM_EMAIL_FILE:
                for match in EMAIL.finditer(text):
                    if not match.group().endswith('@users.noreply.github.com'):
                        issue('non-noreply-email-needs-review', name, text.count('\n', 0, match.start()) + 1)
        for name, text in texts.items():
            for match in re.finditer(r'!?\[[^\]]*\]\(([^)]+)\)', text):
                target = match.group(1).strip('<>')
                if re.match(r'https?://', target) or target.startswith('#'):
                    continue
                target = unquote(target.split('#')[0])
                resolved = posixpath.normpath(posixpath.join(posixpath.dirname(name), target))
                if resolved not in entries and not any(p.startswith(resolved.rstrip('/') + '/') for p in entries):
                    issue('missing-public-link-target', name, text.count('\n', 0, match.start()) + 1)

    if args.history:
        for commit in git('rev-list', '--all').decode().splitlines():
            metadata = git('show', '-s', '--format=%ae%x00%ce%x00%an%x00%cn%x00%B', commit).decode()
            author, committer, author_name, committer_name, message = metadata.split('\0', 4)
            if not all(address.endswith('@users.noreply.github.com') for address in [author, committer]):
                issue('commit-email-not-noreply', commit)
            if HAN.search(author_name + committer_name + message):
                issue('commit-metadata-must-be-english', commit)
            if any(s in metadata for s in needles):
                issue('commit-metadata-private-needle', commit)

    result = {'scope': 'history' if args.history else 'staged' if args.staged else 'tracked-worktree',
              'tree_count': tree_count, 'file_version_count': len(checked), 'issue_count': len(issues), 'issues': issues}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if issues else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, subprocess.CalledProcessError, OSError, ValueError) as error:
        print('Publication check incomplete: ' + type(error).__name__, file=sys.stderr)
        sys.exit(2)
