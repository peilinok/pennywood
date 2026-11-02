# Pennywood

<img src="assets/svg/mascot.svg" width="80" alt="Pennywood squirrel mascot" />

An iPhone / iPad financial-learning app for children aged 7-10 and their parents. Children work toward wishes through agreed real-world work or proactive learning. A parent first checks the work, then confirms actual payment; only then do pocket money and wish progress change.

Source version: **0.3.6+10**. Local storage: **Drift schema 5**. The native wish journal is the main child entry; the Flame town is an optional walk. HTML files are design references.

**Available today: two children on one device, with a local ledger. Automatic cross-device sync is not implemented.** There are no real payment, banking, investment-account, or market-data integrations. Parents fund teaching yields under agreed terms and budgets.

Repository documentation, comments, tooling, paths, and commit messages use English. The app UI, Chinese brand, and Chinese business/test inputs remain in Simplified Chinese.

## Features

- Gift wishes and savings goals; one primary wish, a queue, editing, and archives. Saving enough, receiving a gift, and repaying debt are separate milestones.
- Quick submissions for dishes, mopping, toys, vegetable preparation, and learning; temporary tasks, withdrawal of submissions, specific feedback, and resubmission.
- Separate parent checking and actual payment. Each child has independent tasks, cash, holdings, budgets, advances, and ledger entries.
- Integer-cent accounting, catch-up maturity settlement, cash dividends, reinvestment, parent-funded advances, active monthly repayment, withdrawals, and growth projections.
- SQLite / Drift transactions, idempotency, v1-v4 to v5 migrations, restart recovery, encrypted backups, recovery snapshots, and parent recovery codes.
- Adaptive iPhone portrait/landscape and iPad orientations/windows, light/dark themes, larger text, reduced motion, and accessibility semantics.

Real families start with zero balances, budgets, and rates, with no default passcode, wish, or paid task. Demo families use separately chosen credentials and never populate a real ledger.

## Run locally

Validated baseline: Flutter **3.35.7**, Dart **3.9.2**, Xcode **16.1 / SDK 18.1**, CocoaPods **1.16.2**. Only `ios/` is generated. Both dependency lockfiles are checked in. Drift code generation is not required.

```sh
git clone https://github.com/peilinok/pennywood.git
cd pennywood
flutter pub get --enforce-lockfile
flutter devices
./scripts/run-ios.sh YOUR_IOS_SIMULATOR_ID
```

Put Flutter on PATH or set `PENNYWOOD_FLUTTER` to its executable. To build the simulator app:

```sh
flutter build ios --simulator --debug --no-pub --target lib/main.dart
```

For physical devices, open `ios/Runner.xcworkspace` in Xcode and choose your own development team. Alternatively, create the ignored local file `ios/Flutter/Signing.local.xcconfig` with `DEVELOPMENT_TEAM = YOUR_TEAM_ID`. No personal team, profile, or certificate is checked in. Install upgrades over the existing app to retain its ledger; do not uninstall first.

## Checks and evidence

```sh
./scripts/check.sh
PENNYWOOD_GITLEAKS=YOUR_GITLEAKS_EXECUTABLE ./scripts/check-secrets.sh
./scripts/check-ios.sh
```

The common check covers locked dependencies, formatting, fatal analysis, host/tooling tests, module boundaries, reference cases/prototype builds, and publication/history safeguards. The secret check requires gitleaks 8.30.1 with default rules. The iOS check creates disposable iPhone/iPad simulators for a production build and isolated family/restart flows; it requires macOS/Xcode and an installed runtime. Raw evidence is not uploaded. Use publication `--staged` for actual index blobs and `--history` for all locally reachable commits.

Version 0.3.6 fixes secrets remaining revealed after backgrounding and an incorrect recovery hint. Both regressions failed before the fixes. See [native validation](docs/10-native-validation.md) and the [sanitized summary](evidence/public/validation-summary.json).

Earlier 0.3.5 physical-device validation passed four local core checks on each of an iPhone and iPad, using isolated test ledgers; the production entry was restored afterward. That is not a 0.3.6 physical-device regression. Raw device logs, screenshots, signed packages, and databases are not published. XCTest semantic audits do not replace human VoiceOver testing.

## Documentation

| Topic | Entry |
|---|---|
| Product and modules | [Project overview](docs/00-project-overview.md) |
| Daily use and backups | [User guide](docs/13-user-guide-and-recovery.md) |
| Rules and persistence | [Accounting rules](docs/02-accounting-rules.md), [architecture](docs/05-architecture-and-storage.md) |
| Interaction and visual design | [Wishes and sharing](docs/08-wishes-and-family-sharing.md), [UI / UX](docs/09-wish-journal-ui-ux.md), [design system](design-system/pennywood/MASTER.md) |
| Adaptation and remaining work | [Adaptive validation](docs/11-adaptive-layout-validation.md), [delivery checklist](docs/12-delivery-checklist.md) |
| Review and publication | [Project review](docs/21-project-review.md), [privacy checks](docs/22-publication-and-privacy.md) |
| AI work and regression prevention | [Contributing](CONTRIBUTING.md), [feature matrix](docs/23-feature-regression-matrix.md), [code/test standards](docs/26-code-and-test-standards.md) |
| Versions, recovery, and decisions | [Release policy](docs/24-versioning-and-release.md), [data compatibility](docs/25-data-compatibility-and-recovery.md), [ADRs](docs/adr/README.md), [changelog](CHANGELOG.md) |

## Reference prototypes

```sh
python3 prototype/wishboard/build.py
python3 prototype/interaction-lab/build.py
```

These generate offline HTML in the ignored `outputs/` directory. Preview balances, child names, passcodes, and send/receive controls are synthetic demonstrations, not CloudKit or live family data. `reference/` contains the reference rules and 26 migration cases; production accounting is implemented in Dart.

## Remaining work

CloudKit round trips, same-account device authorization, production sync, offline retries, out-of-order delivery, and multiple-parent conflicts remain unimplemented. iCloud signing requires an eligible developer team; a free Personal Team cannot enable it. Unsigned compilation is not cloud validation. Saving an encrypted backup to iCloud Drive is file backup, not synchronization.

Complete physical-device backup/finance regression, human VoiceOver testing, iPadOS 26 windows, and longitudinal child testing remain pending. No TestFlight or App Store release has been made.

## Public repository boundary

Only reviewed source, assets, rules, synthetic fixtures, prototype source, and sanitized summaries are published. `work/`, `outputs/`, raw `evidence/`, family databases/backups, device identifiers, signing data, and generated local configuration remain ignored and local. Commits use GitHub noreply identities. See [publication and privacy](docs/22-publication-and-privacy.md).
