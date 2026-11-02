# Architecture and Persistence

Production entry: `lib/main.dart`. The project generates only `ios/`. HTML remains a reference and is not hosted inside the app.

| Directory | Boundary |
|---|---|
| `lib/domain/` | Pure Dart money, calendar, accounts, work, investments, dividends, advances, repayments; no Flutter, Flame, or Drift imports |
| `lib/data/` | Drift parameterized SQL, normalized rows, transactions, migrations, Keychain credentials, permissions, unified business entry |
| `lib/app/` | Family creation/selection, child switching, lifecycle, paper theme, action coordination |
| `lib/game/` | Flame loop, load-time assets, layers, foot-depth sorting, collision-sampled A*, camera/state |
| `lib/features/` | Six wish-journal pages and native savings, advance, repayment, growth, classroom panels |

## Accounting commit

`TownService.execute` validates scope and parent capability, enters a Drift transaction, catches up settlements by family date, runs pure Dart rules, checks conservation/budget, and writes account/business rows, append-only ledger, and operation records. Flutter/Flame refreshes after persistence. An identical request with the same operation ID is idempotent; changing its contents is rejected. Business state and unique ledger indexes also prevent repeated payment/settlement.

Drift uses custom normalized SQL, so no `build_runner` step is required. Tables cover families, children, wishes, quick-task agreements, task instances, holdings, withdrawals, loans, installments, actual repayments, ledger, operations, scene, footprints, and two wish/payment association tables. Command fingerprints may be JSON; account state and the ledger are not stored as one JSON blob.

Cash, principal, and budgets are integer cents. BigInt intermediate arithmetic uses denominators 3650000 for daily annual-bps yield and 120000 for monthly annual-bps interest, with half-up cent rounding. Positions snapshot rate, term, start/maturity, expected yield, distribution mode, and terms version. Raising a rate and changing it back still requires renewed acceptance.

Real families start with zero cash, labor income, budget, and rate. Demo families have separate IDs, user-chosen credentials, explicit synthetic principal sources, and an independently replaceable clock. Demo acceleration cannot change a real family's date.

## Storage and permissions

`pennywood.sqlite` lives in Application Support. Schema 5 supports v1/v2/v3/v4 upgrades while preserving legacy operations, roles, task agreements/instances, wishes, balances, and ledger. Additions include stable random family identity, wish archives/deletion tombstones, savings milestones, and gift-payment associations. Before migrating a file database, SQLite `VACUUM INTO` saves a consistent `.before-vN.sqlite` snapshot. Backup failure stops migration; unknown upgrade paths fail without clearing data. Tests cover upgrades, file reopen, and failed-write rollback.

A 6-12 digit parent passcode uses a random salt and 100000 PBKDF2-HMAC-SHA256 iterations. Only its derived value is in local Keychain, not the database. Wrong attempts are throttled. Parent capabilities are issued in memory and expire on leaving parent space, switching child, or entering inactive/background state; late unlock computation cannot reauthorize. Each capability binds family and child. Parents can verify the old passcode to change it or generate a separate 128-bit recovery code. The code is shown once; a new code replaces the old. Recovery resets the passcode without changing the ledger.

`lib/data/backup.dart` implements explicit encrypted backup/recovery with 210000 PBKDF2-HMAC-SHA256 iterations and AES-256-GCM. It exports only the current family's normalized rows, ledger, operation IDs, and scene, never Keychain credentials. The format header is authenticated. Import validates ownership, foreign keys, conservation, and ledger in an isolated in-memory database first. Existing families require a valid local capability and the same stable identity; persist an encrypted pre-restore copy before transactional replacement. New installations set a separate local passcode; retained Keychain credentials still require verification.

`lib/features/family_settings.dart` and the iOS `pennywood/files` channel provide system file pickers. Documents holds exportable files; the live database is not exposed to Files. Encrypted row serialization is an explicit archive, not daily accounting or future synchronization.

Persist character position, camera, afternoon/dusk, sound preference, and footprints on arrival, panel entry, child switching, and backgrounding. Window changes reuse state. Footprints never earn money.

## Dependencies

Flutter 3.35.7, Dart 3.9.2, Flame 1.32.0, Drift 2.28.2, sqlite3_flutter_libs 0.5.39, flutter_svg 2.2.0, path_provider 2.1.5, flutter_secure_storage 9.2.4, cryptography 2.7.0. Direct versions are pinned; `pubspec.lock` and `ios/Podfile.lock` retain resolved dependencies. SDK requirements were checked and built with Xcode 16.1. SVGs parse at load time; the squirrel artwork supplies the app icon.

The upstream SQLite podspec is pinned in `ios/Specs/`; see its source/download-host note. No other platform project is generated.

## Wish journal

`lib/features/wish_home.dart` supplies three child and three parent pages; `lib/app/paper_theme.dart` implements design-system 0.3 light/dark colors. `WishHome` is the entry, and the town remains in More using the same controller/service.

A partial unique index allows at most one primary wish per child. Legacy goal fields stay synchronized for existing growth/advance panels. Queued wishes never duplicate cash. Wishes can be edited, archived, and tombstoned; finishing a primary wish clears the slot until an explicit next choice. Saving enough records a milestone without payment. Gift receipt links actual delivered withdrawals and funded principal whose sum must equal the purchase cost. Links cannot be reused, and receipt does not debit again or erase debt. Linked wishes cannot be deleted or converted to savings goals; they may be archived. One active advance remains the limit, while historical repaid advances may join multiple purchase payments.

`quick_tasks` stores parent agreements. Each `tasks` instance snapshots template ID, business day, payment, standard, status, and feedback. A partial unique index permits one instance per child/template/day. Pending prior-day instances remain visible. Withdrawal and resubmission reuse the same instance; all actions append ledger entries. Real families have no default paid tasks. Pausing an agreement stops new instances but preserves old promises. Temporary tasks are editable/deactivatable before acceptance; accepted terms remain fixed. History distinguishes inactive and paid tasks.

The local app shares one ledger directly and does not fake cloud delivery. Device sync/authorization remain pending. Native acceptance uses isolated databases and Keychain namespaces. See [validation](10-native-validation.md) and [recovery](13-user-guide-and-recovery.md).

## Schema 5 payment associations

`wish_withdrawals` and `wish_loans` uniquely identify each family/child/payment and use composite foreign keys for wish/payment ownership. `received=0` binds a request; `received=1` includes it in gift receipt. One payment cannot fund multiple wishes or be reused. Old `wishes.withdrawal_id/loan_id` columns are migration-only, not current business sources. v4 migration creates relation rows for old single-payment receipts without changing accounts or ledger.

The new authenticated header is `Pennywood-encrypted-backup:1:schema5`; schema4 ciphertext remains accepted. Decrypt using its actual header, reconstruct legacy relations, and validate amounts/payment states in the new in-memory schema without rewriting the source archive. `test/fixtures/backup-schema4.json` is synthetic; its test password is not a family credential. See the [checklist](12-delivery-checklist.md).
