# Changelog

Record user-visible changes and data compatibility in English. Release entries are immutable after tagging; corrections belong in a later entry. GitHub source publication is not App Store or physical-device acceptance.

## Unreleased

### Engineering

- Add a contribution contract, stable regression IDs, release/recovery standards, code/test standards, and an ADR process for human and AI work.
- Add PR ownership/templates, mandatory repository and iOS simulator CI, and full-history secret scanning. Review GitHub protection settings separately from files in this repository.
- Align the Podfile checksum in the lockfile without changing dependency versions; pin CI CocoaPods to 1.16.2.
- Keep version 0.3.6+10, Drift schema 5, accounting, and the encrypted-backup format unchanged. Increment the app/build before the next binary distribution.

### Fixed

- Stack the finance-panel illustration and dialogue in narrow windows to prevent overflow found by the new simulator gate.
- Wait for native backup-save completion before asserting the widget result; retain all export/credential assertions.

## 0.3.6+10 - Local-feature baseline

- Conceal revealed secrets and clear secret input on leaving the foreground while retaining ordinary forms.
- Correct onboarding guidance for parent recovery codes.
- Publish English repository material and ASCII paths while preserving Chinese UI and business inputs.
- Preserve normalized local accounting, two-child isolation, wish/task workflows, encrypted backup/recovery, and schema 1-4 upgrades to 5.

Source baseline: `0ac9298829c47e3df4160a41dae6a0cb3f9424ad`, tag `v0.3.6-local.1`. See the [baseline manifest](evidence/public/releases/v0.3.6-local.1.json). This is a local-feature recovery point; CloudKit and complete physical-device regression remain pending.
