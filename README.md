# Pennywood

The 0.5.0+12 simplification candidate is being delivered in bounded tasks under [the implementation plan](docs/27-interface-simplification.md). S1 focuses the wish home and task actions; S2 gives wishes sequential list/detail/edit/receipt pages and explicitly linked advance proposals; S3 consolidates money, direct withdrawals, grouped plans, and read-only learning; S4 separates parent pending work, child settings, and shared family settings. Retain schema6 and all payment/permission rules. S5 retires the town business entry, moves appearance under More, and restores returning real families directly to the journal. Task status and exact-candidate checks belong to that plan and each PR; physical usability remains separate acceptance.

<img src="assets/svg/mascot.svg" width="80" alt="Pennywood squirrel mascot" />

An iPhone / iPad financial-learning app for children aged 7-10 and their parents. Children work toward wishes through agreed real-world work or proactive learning. A parent first checks the work, then confirms actual payment; only then do pocket money and wish progress change.

Source candidate: **0.5.0+23** (synthetic nearby browser-handoff experiment). Local storage: **Drift schema 6**. The native wish journal is the main child entry; the standalone town route and duplicate business panels are retired by ADR 0003; scene data and internal tests remain. HTML files are design references.

**Available today: two children on one device, with a local ledger. Automatic cross-device sync is not implemented.** There are no real payment, banking, investment-account, or market-data integrations. Parents fund teaching yields under agreed terms and budgets.

Repository documentation, comments, tooling, paths, and commit messages use English. The app UI, Chinese brand, and Chinese business/test inputs remain in Simplified Chinese.

## Features

- Gift wishes and savings goals; one primary wish, a queue, editing, and archives. Saving enough, receiving a gift, and repaying debt are separate milestones.
- Family-wide task standards/pay and independently configurable rates for sapling, annual, and fixed dividend plans.
- Quick submissions for dishes, mopping, toys, vegetable preparation, and learning; temporary tasks, withdrawal of submissions, specific feedback, and resubmission.
- Separate parent checking and actual payment. Each child has independent tasks, cash, holdings, budgets, advances, and ledger entries.
- Integer-cent accounting, catch-up maturity settlement, cash dividends, reinvestment, parent-funded advances, active monthly repayment, withdrawals, and growth projections.
- Parent-enabled real-money low/high-volatility teaching plans, bounded 30-day gains/losses, maximum-yield reservation, and signed realized returns. Indicative prices are separate from the cost-based ledger until redemption/maturity.
- Interactive native curve playback, dividend allocation animation, and compounding comparisons with pause, time stepping, and reduced motion.
- SQLite / Drift transactions, idempotency, v1-v5 to v6 migrations, restart recovery, encrypted backups, recovery snapshots, and parent recovery codes.
- Adaptive iPhone portrait/landscape and iPad orientations/windows, light/dark themes, larger text, reduced motion, and accessibility semantics.

Real families start with zero balances, budgets, and rates, with no default passcode, wish, or paid task. Demo families use separately chosen credentials and never populate a real ledger.

## Run locally

Validated baseline: Flutter **3.35.7**, Dart **3.9.2**, Xcode **16.1 / SDK 18.1**, Ruby **4.0.5**, CocoaPods **1.16.2**, JSON gem **2.18.0**. Use this JSON version with CocoaPods: older formatters change spec checksums even when pod versions match. Only `ios/` is generated. Both dependency lockfiles are checked in. Drift code generation is not required.

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

The [0.5 simplification validation summary](evidence/public/interface-simplification-validation.json) separates host, simulator and remaining human/device acceptance. Exact-head required CI belongs to each PR in the delivery plan; a simpler structure is not proof of child usability.

The 0.4.0 baseline fixed finance-dialog closure locking the parent area, shared recurring family agreements, separated product rates, and added real-money teaching investments and interactive lessons. Schema 6 accepts schema4/5/6 backups; older apps cannot open upgraded live data. Upgrade snapshots select the previously active child's future templates as the family starting point and retain all prior task/holding promises. See the [experience decision](docs/adr/0002-shared-agreements-and-teaching-market.md) and [0.4.0 local validation summary](evidence/public/experience-validation.json); physical-device acceptance remains pending. Earlier results remain in [native validation](docs/10-native-validation.md) and the [historical summary](evidence/public/validation-summary.json).

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
| Experience changes | [Shared terms and teaching market](docs/adr/0002-shared-agreements-and-teaching-market.md) |
| Versions, recovery, and decisions | [Release policy](docs/24-versioning-and-release.md), [data compatibility](docs/25-data-compatibility-and-recovery.md), [ADRs](docs/adr/README.md), [changelog](CHANGELOG.md) |

## Reference prototypes

```sh
python3 prototype/wishboard/build.py
python3 prototype/interaction-lab/build.py
```

These generate offline HTML in the ignored `outputs/` directory. Preview balances, child names, passcodes, and send/receive controls are synthetic demonstrations, not CloudKit or live family data. `reference/` contains the reference rules and 26 migration cases; production accounting is implemented in Dart.

## Optical camera probe

For the separate synthetic optical test, build with `flutter build ios --release --target lib/particle_probe_main.dart`. Open the probe on both devices, select Display and tap Full-screen display on iPad, then enable the camera on iPhone. The optical action opens no family database or credentials, saves no camera frames and establishes no network connection. A separate nearby-test action is described below. Normal `lib/main.dart` builds retain the family app. Install updates without uninstalling; return to a normal build to access the retained ledger. See the [probe contract and evidence](docs/research/particle-camera-probe.md).

Physical trials of builds 13 and 14 were unreliable. Build 15 retains the camera's native 720p luma instead of reducing it with nearest-neighbor sampling, which erased readable blurred particles in a reproduced capture-path regression. In Camera mode, aim at the complete field for about ten seconds, then tap Copy diagnostic summary and share the text. The summary contains numeric capture/localization/decoding counts, confidence, processing time and camera focus/exposure metadata; no images or recovered payloads are copied. Physical reliability remains unverified.

Build 15's physical summary included four valid decodes; the owner reports no successful confirmation. Build 16 repaired intermittent-frame confirmation, and build 17 retained erasure correction while adding a fully validated hard-decision attempt for uncertain samples. Both mechanisms have synthetic regressions, but build 17 still physically failed: 30 frames, 21 geometric matches, zero decodes and 93 minimum uncertain bytes despite near-full framing. These repairs have not established the physical root cause.

Build 18 adds diagnostic rings around candidate centers and a dashed boundary around the current sampling region. Check whether all five real locator constellations have rings and whether the dashed boundary follows the inner data field. The copied numeric summary adds the best candidate's field dimensions, minimum bit-position spacing, mean luminance difference and fifth-point error. A geometric candidate is not proven localization or a valid payload. No images or recovered payloads are saved/copied; recognition and confirmation decisions are unchanged. The owner completed one build 18 physical confirmation after 13.3 seconds, with three valid decodes; all five rings and the sampling outline aligned. This single trial does not establish reliability.

Build 19 adds a clean full-screen particle display with no visible lettering, an accessible 44 pt exit icon, and adaptive layout. On iPad, tap **Full-screen display** before scanning; the exit icon returns to the controls. Locator ranking also penalizes irregular glyph boundaries, preserving readable fields when tiny satellites disappear. Fixed-label regressions reproduce the text interference, but the old text-heavy control page remains less robust under small/blurred capture. The full-screen route is the intended optical display. Camera settings, full validation and two-frame confirmation are retained; the owner reports 5/5 successful build 19 trials at about one second, with one copied summary confirming in 0.5 seconds. The additional 15/15 ordinary-condition trials met the three-second criterion, giving 20/20 across reported sessions; the additional report does not specify its build. The broader lighting/geometry/negative matrix remains pending.

## Synthetic nearby connection probe

The same separate entry now offers **Start two-device connection test**. On one device choose **Display temporary pairing image**; on the other choose **Scan and pair**, then enable its camera. Allow local-network access when prompted. The display is text-free and expires after two minutes. After scanning, the display device must choose **Confirm admission**. Both sides persist an isolated pending test credential, reconnect using that permanent credential, and exchange acknowledged synthetic messages. Completion here is neither family authorization nor financial synchronization.

After a completed pair, or after an interrupted durable activation, open this page on both devices and tap **Sync test messages**. No new scan is requested. Cancel/background stops the foreground session; retry retains saved trust. **Forget test pairing** removes only the local probe item; forget on both devices before intentionally starting a new pair. A failure before the second device receives its durable offer may require this explicit reset. No real database, schema6 archive, parent credential, balance or family grant is opened or changed.

The test uses Bonjour and peer-to-peer-enabled Network TCP with strict TLS 1.2 PSK / AES-128-GCM negotiation. It has no plaintext fallback or forward secrecy. No-common-router operation, real permission recovery and device restart acceptance remain physical gates. The native suite uses certificate-free ad-hoc simulator signing so isolated Keychain behavior is actually tested. See the [API research, implementation contract and acceptance](docs/research/nearby-enrollment-probe.md).

Build 21 encodes the complete PSK identity as Base64 ASCII at the Network API boundary. Build 20 can fail authentication when a random identity contains a zero byte, even with matching keys. Stored credentials, secret bytes and the optical format are unchanged; update both test endpoints before retrying. Same-bundle updates retain the saved pair; current device acceptance is recorded below.

The owner reports first enrollment on build 20, saved-pair reconnect after upgrading both devices to build 21, and successful reconnect after force-quitting/reopening both apps. The guided no-common-router/no-internet trial then timed out on iPhone; router-free acceptance is not met. Build 22 retains build, role, last stage/state, TLS confirmation, protocol phase, message counters, path categories, numeric error categories and elapsed time in the copied failure summary before stopping. No credential, discovery name, endpoint or payload is exported. It preserves the same keys, transport parameters and deadlines; this is a diagnostic update, not a claimed radio repair.

Build 22 completes saved-pair exchange on shared Wi-Fi in the owner's two-endpoint summaries (0.3/1.5 seconds), but both Control Center disconnection and a Settings Wi-Fi restart without joining a network stall before TLS; the display endpoint accepts no connection. Build 23 changes one variable: retain the selected browser until connection readiness, then stop browsing before application exchange. Failure, cancel and background still stop it within the existing deadlines. Apple recommends stopping peer-to-peer browse before connection for performance; this bounded old-API experiment tests a handoff hypothesis, not a confirmed repair. No simulator result establishes its radio effect. Preserve the pair and collect both physical summaries.

## Remaining work

The accepted next direction is [one-time custom particle camera pairing and nearby Wi-Fi synchronization](docs/28-nearby-family-sync-plan.md), with one primary accounting device and scoped companions, under [ADR 0004](docs/adr/0004-nearby-family-sync.md) and [ADR 0005](docs/adr/0005-custom-particle-pairing.md). The [optical format](docs/29-particle-pairing-code.md) now has experimental native optical and synthetic nearby enrollment probes; full physical optical/network acceptance, production pairing, offline requests, transactional replication and family recovery remain pending. CloudKit and independent financial writers are deferred. Saving an encrypted backup to iCloud Drive remains file backup, not synchronization; neither a simulator build nor this plan proves real device exchange.

Complete physical-device backup/finance regression, human VoiceOver testing, iPadOS 26 windows, and longitudinal child testing remain pending. No TestFlight or App Store release has been made.

## Public repository boundary

Only reviewed source, assets, rules, synthetic fixtures, prototype source, and sanitized summaries are published. `work/`, `outputs/`, raw `evidence/`, family databases/backups, device identifiers, signing data, and generated local configuration remain ignored and local. Commits use GitHub noreply identities. See [publication and privacy](docs/22-publication-and-privacy.md).
