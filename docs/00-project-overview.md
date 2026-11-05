# Project Overview

Candidate 0.5.0+12, 2026-11-03. Pennywood is a wish-driven local family financial-learning app for iPhone and iPad. Child actions stay short; parents explicitly check work and confirm payment. The production town entry is retired by ADR 0003, and orientation is adaptive.

## Complete user path

Create a zero-balance family -> add a child's wish -> agree on real work and payment -> child submits using a task icon -> parent checks -> parent confirms actual delivery or reserved custody -> Drift commits -> cash and wish progress update -> terminate/restart and recover.

Work, proactive learning, and temporary tasks build savings. Investments arrange existing funds; advances are actual purchases funded by a parent. Expected yields and borrowed amounts do not count as the child's own savings. Children are independent, and queued wishes do not duplicate account assets.

## Module boundaries

| Directory | Responsibility |
|---|---|
| `lib/domain` | Pure Dart amounts, dates, tasks, holdings, dividends, advances, and repayments |
| `lib/data` | Normalized Drift tables, transactions, migrations, idempotency, permissions, encrypted backup/recovery |
| `lib/app` | Initialization, family entry, controller, lifecycle, theme, scroll semantics |
| `lib/features` | Six child/parent destinations, sequential finance pages, task management, family settings |
| `lib/game` | Retained internal Flame scene/navigation/lifecycle harness, collision, occlusion, camera and stored footprints |
| `ios` | iOS project, Keychain integration, native file pickers, orientation declarations |
| `test` / `integration_test` | Rules, database, widgets, isolated-ledger integration tests |
| `prototype` / `reference` | Rebuildable prototypes and synthetic accounting migration cases |

Amounts change through `TownService.execute`: validate scope, settle due items within a transaction, persist state/ledger/operation identifiers, then refresh UI. The database stores business rows rather than replacing an entire JSON ledger.

## Status and next steps

Local tasks, two children, wish lifecycle, payment associations, finance, advances, and recovery are implemented. The 0.5 simplification candidate consolidates navigation under the delivery plan. Schema remains 6 and authenticated archive4/5/6 readers stay intact; no accounting, credential or data conversion changes occur. Native candidate evidence and physical/human acceptance remain distinct.

CloudKit and device authorization are not implemented. Sharing an Apple Account does not grant parent permission. Next: eligible signing/container -> isolated real two-device round trip -> sync/authorization protocol -> submission-to-payment loop -> remaining money operations, multiple-parent conflicts, and offline recovery. Do not put an active SQLite file in iCloud Drive for concurrent writers.

See [validation](10-native-validation.md) and the [delivery checklist](12-delivery-checklist.md). Raw device evidence and old archives remain local. Historical results are not new validation of this version.
