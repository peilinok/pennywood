# Publication and Privacy Checks

Publish reviewed project material only. The public GitHub account is the user-selected destination. Commit author/committer identities use its GitHub noreply address, not a private system email.

## Included

Flutter/Dart source, iOS templates, assets, product/rule documents, lockfiles, rebuildable prototype source, synthetic accounting cases, and sanitized summaries. Fixed test passcodes/names/ciphertext/dates are synthetic, never real family credentials. Production onboarding has no default passcode or funds.

Repository documentation, comments, test descriptions, tooling, paths, and commit messages use English. Product-facing Chinese copy, brand, and Chinese business inputs remain localized.

## Excluded

- Family SQLite/WAL/SHM, encrypted backups, passcodes/recovery codes, Keychain, real business records.
- Device names/identifiers, pairing records, Apple accounts, personal teams, profiles, signing certificates, private keys.
- Personal absolute paths, generated Flutter configuration, Xcode user state, raw logs/xcresult, sandboxes, device screenshots.
- `work/`, `outputs/`, old delivery archives, build artifacts, downloaded tools, caches, unreviewed reference images.

Preserve originals locally rather than deleting them to pass scanning. Root/document directories use an allowlist. Personal signing stays only in ignored `ios/Flutter/Signing.local.xcconfig`; simulators build without it.

## Checks

1. Inspect actual staged paths, not a whole-directory copy.
2. `scripts/check-publication.py --staged` reads index blobs and checks scope, prohibited files, personal paths, credential/device patterns, documentation language, filenames, and local links.
3. Use the official checksum-verified gitleaks release with default rules, redacted output, no baseline/custom allowances, and local-only reports.
4. Inspect every reachable commit tree and author/committer metadata; require noreply email and English names/messages. Never import raw workspace history.
5. Independently export the candidate tree and verify lockfiles, format, analysis, tests, prototypes, and simulator build without local signing configuration.
6. After pushing, compare remote branch SHA and file objects with the scanned local commit.

`--private-needles` optionally reads a local JSON list of exact private strings. Keep this list ignored; never copy its contents into public source/reports. Failures report only rule, path, and line, without echoing secret values.

The locked upstream podspec may retain public author attribution/download URLs; these are not local credentials. Do not modify dependency checksums to remove upstream credit. App PNGs contain only required image blocks, with no text/EXIF metadata. Device screenshots are not public.

## History replacement

The user requested replacing the initial two commits with a single English root commit. Preserve the old Git bundle and tracked-file archive under ignored local work, not a public ref. Capture the expected remote SHA before rewriting and use `--force-with-lease`, never an unconditional force. If the remote changed, investigate instead of overwriting another contributor.

After replacement, all published branch/tag history must lead only to the new English history. Existing clones must re-clone or deliberately realign without reintroducing old commits. A force push changes reachable refs; GitHub may retain unreachable object URLs/caches until its own cleanup. It is not a guarantee of immediate object erasure from the hosting provider.

Checks have a defined scope and do not guarantee future changes are risk-free. Review the tracked set on every publication: `.gitignore` does not remove tracked files. Never use `git add -f` to bypass exclusions.
