# Changelog

Record user-visible changes and data compatibility in English. Release entries are immutable after tagging; corrections belong in a later entry. GitHub source publication is not App Store or physical-device acceptance.

## Unreleased

### Simplification candidate 0.5.0+12

- Focus the wish home on its goal and one concrete feedback hint; keep the complete configured task area in Tasks.
- Submit accepted temporary tasks directly from their cards, retain paused/cross-day promises, and preserve each child's page scroll when changing tabs or window size.
- Navigate wishes through list/detail/edit/receipt pages, make the complete primary card tappable, preserve the originating context after editing, and start explicitly linked gift advances from the child's wish detail. Keep amount/progress semantics independently readable and actual gift receipt parent-only.
- Give money one primary available balance, directly reachable holding/debt records, a recent/full classified ledger, and a direct withdrawal form. Group five plans by fixed/variable terms and confirm deposits once with amount-specific promises and risk; retain invalid input for correction. Consolidate hypothetical growth and weekly contributions in the interactive classroom, separate from actual returns.
- Separate parent Pending, Child, and Family responsibilities. Handle money handover and advance offer/funding directly from each pending record, exclude child-waiting offers from actionable counts, separate budget/name forms, and retain one profile selector and one temporary-task creation entry. Keep internal-page close separate from exit/background locking.
- Retire the production town route and duplicate task/wish/wallet/parent/growth panels under ADR 0003; keep scene data, assets and internal lifecycle/navigation tests. Move appearance under More, default to system, label parent access, remove routine saved-state badges, and return existing real families directly to the selected child while keeping demos/explicit home return separate. Wait for route disposal before disposing its controller.
- Retain schema6, authenticated schema4/5/6 backups, existing task/holding promises, and all financial/parent rules. See the [implementation plan](docs/27-interface-simplification.md) and [ADR 0003](docs/adr/0003-wish-journal-simplification.md) for the remaining bounded tasks.

### Experience candidate 0.4.0+11

- Preserve the parent session when its nested finance dialog closes; retain exit/profile/background locking.
- Share recurring task standards/pay across the family while keeping task instances, funds, budgets, and permission separate.
- Set independent family rates and versions for the three existing fixed products; preserve original holding promises.
- Add parent-enabled, real-money low/high-volatility teaching plans with bounded 30-day gains/losses, budget reservation, and signed settlement.
- Replace the prose classroom with native curve playback, random alternative journeys, compound-growth comparisons, and dividend animations; support time stepping, pause/resume, and reduced motion.
- Upgrade schema1-5 to schema6, retain legacy templates and original snapshots, and read authenticated schema4/5/6 backups. The active child's future templates initialize shared terms; older binaries cannot read upgraded live data. See [ADR 0002](docs/adr/0002-shared-agreements-and-teaching-market.md).

### Engineering

- Add a contribution contract, stable regression IDs, release/recovery standards, code/test standards, and an ADR process for human and AI work.
- Add PR ownership/templates, mandatory repository and iOS simulator CI, and full-history secret scanning. Review GitHub protection settings separately from files in this repository.
- Align the Podfile checksum in the lockfile without changing dependency versions; pin CI Ruby 4.0.5, CocoaPods 1.16.2, and JSON 2.18.0. Check deployment-mode pod metadata before native builds.
- Attach native tests through authenticated, process-scoped retained simulator logs to avoid Flutter's live-log startup race; keep independent restart and all business assertions.
- Governance-only changes retained the 0.3.6+10/schema5 baseline. The experience candidate above advances app/build, schema, and archive payload; no binary distribution is implied.

### Fixed

- Stack the finance-panel illustration and dialogue in narrow windows to prevent overflow found by the new simulator gate.
- Wait for native backup-save completion before asserting the widget result; retain all export/credential assertions.

## 0.3.6+10 - Local-feature baseline

- Conceal revealed secrets and clear secret input on leaving the foreground while retaining ordinary forms.
- Correct onboarding guidance for parent recovery codes.
- Publish English repository material and ASCII paths while preserving Chinese UI and business inputs.
- Preserve normalized local accounting, two-child isolation, wish/task workflows, encrypted backup/recovery, and schema 1-4 upgrades to 5.

Source baseline: `0ac9298829c47e3df4160a41dae6a0cb3f9424ad`, tag `v0.3.6-local.1`. See the [baseline manifest](evidence/public/releases/v0.3.6-local.1.json). This is a local-feature recovery point; CloudKit and complete physical-device regression remain pending.
