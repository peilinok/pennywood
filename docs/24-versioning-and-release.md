# Versioning and Release

## Branches and GitHub gates

`main` is the integration branch. Use short-lived `feat/*`, `fix/*`, `chore/*`, or `docs/*` branches and one bounded PR per task. A permanent `develop` branch is unnecessary for this project.

Protect `main` with a PR requirement, strict up-to-date checks named `Repository checks` and `iOS simulator`, resolved conversations, linear history, and no force pushes/deletion. Apply the rules to administrators, with no routine bypass. For a solo maintainer, require zero external approvals rather than an impossible second-account approval. CODEOWNERS identifies responsibility; it does not replace review. Configure squash-only merges and deletion of merged feature branches. Required check names must match the workflow exactly.

Protect existing `v*` tags against update and deletion with an active tag ruleset. A tag is a recovery marker, not proof of acceptance. Do not create a tag until its source has passed the stated checks. Repository files cannot enforce hosting settings by themselves: verify actual GitHub API settings and record them in sanitized evidence. If the account cannot enable a rule, report that limitation rather than claiming protection exists.

The initial hosting configuration was read back on 2026-11-02; see the [sanitized settings snapshot](../evidence/public/governance-setup.json). It is a dated observation, not proof that future settings remain unchanged.

CI runs on PRs and `main` pushes and checks the exact PR head or pushed commit. Strict up-to-date protection requires the PR to include current `main` before merge; conflicts block merging. Checking the real head also avoids treating GitHub's temporary synthetic merge identity as a published author. CI uses a read-only token, no family data, and no signing/cloud secrets. Actions are pinned to full commit hashes. No `pull_request_target`, self-hosted runner, production ledger, auto-publish, or automatic merge is used. Required jobs run even for documentation-only changes so protection cannot wait forever on a skipped job.

## Three independent versions

| Version | Current baseline | Change rule |
|---|---|---|
| App version/build | `0.3.6+10` | Increment patch for fixes, minor for compatible features, major for intentional incompatible product behavior. Any distributed binary gets a higher build number. Documentation-only changes need no app bump. Pre-1.0 status never excuses data loss. |
| Drift schema | `5` | Increment only for persisted schema changes. Ship explicit migrations and compatibility tests; do not edit a released migration to mean something else. |
| Encrypted archive | `Pennywood-encrypted-backup:1:schema5` | Treat encryption/envelope and payload-schema compatibility separately. Current reader accepts schema4 and schema5; changing one requires authenticated fixtures and restore tests. |

Dependencies remain locked in `pubspec.lock` and `ios/Podfile.lock`. Baseline local toolchain is Flutter 3.35.7 / Dart 3.9.2, Xcode 16.1 / SDK 18.1, CocoaPods 1.16.2. Hosted CI uses macOS 15 with Xcode 16.4 / iOS 18.5 simulators and the same Flutter version. CI records installed tool versions; toolchain changes need their own validation and must not silently regenerate locks.

## Release sequence

1. Freeze a candidate commit after required checks. Run additional checks for affected [feature IDs](23-feature-regression-matrix.md) and complete physical-device acceptance before claiming a family release.
2. For storage/auth/backup changes, create and verify an encrypted backup first. Exercise upgrade/restart/restore using synthetic copies. Define code rollback versus forward data repair under the [recovery policy](25-data-compatibility-and-recovery.md).
3. Update app/build where needed, changelog, release-specific status, and a sanitized JSON manifest under `evidence/public/releases/`. State source SHA, intended tag, toolchain, app/schema/archive versions, accepted inputs, downgrade limits, checks/evidence, and pending work. Do not include paths, device IDs, credentials, archives, or raw logs.
4. Review the exact staged/public commit and complete reachable history, including the new tag annotation. Use publication checks and default-rule, redacted gitleaks. Commit only reviewed paths with noreply identities and English messages.
5. Merge through the protected PR. Create an annotated tag, normally `vMAJOR.MINOR.PATCH` or an explicitly named prerelease/local baseline. Use an English annotation containing the source SHA and compatibility summary; verify remote SHA/tag target after push. Never move an existing tag.
6. Installation, TestFlight, App Store upload, and public release announcements require authorization for that distribution. Install upgrades over the existing app; do not uninstall to make an upgrade test pass.

`v0.3.6-local.1` identifies the pre-governance source commit documented in the [baseline manifest](../evidence/public/releases/v0.3.6-local.1.json). It preserves the existing local-feature checkpoint; it does not assert fresh physical tests or completed sync.

## Regressions and recovery

Stop release distribution on a confirmed financial, permission, or persistence regression. Preserve failing synthetic reproduction and the affected version. Prefer a focused forward fix; use `git revert` in a new branch/PR for code-only regressions when data compatibility permits. Do not reset public `main` or reinstall an older app over newer data without compatibility evidence. Never label a restored older backup as lossless: transactions after its timestamp are absent.

CI success proves only its defined scope. A simulator build, simulator runtime, physical-device result, and human accessibility check are separate facts. Keep raw logs/backups local and retain a small sanitized result manifest with durable links to CI runs.
