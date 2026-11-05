# Native Validation Record

Historical source records start at 0.3.6+10/schema5; the current candidate is 0.5.0+12/schema6. Publish sanitized summaries only. Device identifiers, personal names, raw logs, xcresult, sandboxes, screenshots, and signed packages stay local and out of Git history.

## Simplification candidate

Candidate 0.5.0+12 retains schema6 and unchanged accounting/storage rules. The [S1-S5 plan](27-interface-simplification.md) and [sanitized validation summary](../evidence/public/interface-simplification-validation.json) identify the changed navigation, host checks and isolated simulator journeys. Required family targets include finance and independent-process replay checks. Exact-head hosted CI belongs to each PR. Physical-device, human child/VoiceOver and current system-window acceptance remain separate and pending; historical results below do not establish them.

## Version 0.3.6

Before the review fixes, locked dependencies, formatting, static analysis, and 98 host tests passed. Two regressions were observed failing before repair: secret inputs must clear/conceal on leaving the foreground while ordinary inputs remain; onboarding must explain generating a recovery code. One lifecycle test was added and the existing onboarding assertion strengthened, bringing the host total to 99.

See the [historical public summary](../evidence/public/validation-summary.json) for that candidate's checks, source-tree verification, simulator builds, and startup scope. Its simulator smoke checked only the production entry, not the entire business flow. That 0.3.6 validation did not reinstall or retest physical devices; it is not a statement of their currently installed version.

Repository-language maintenance translates documentation, comments, test descriptions, and tooling without changing production Chinese copy, accounting, or schema. Its own check results are recorded separately in the public summary.

## Historical 0.3.5 device evidence

| Check | Recorded result | Scope |
|---|---|---|
| Host | 98 tests, formatting, analysis passed | 26 accounting cases, permissions, migration, persistence, backup/recovery, widgets |
| iOS 18.1 simulators | Four native XCTest checks on each iPhone/iPad | Description completeness, amount explanations, button role/hits, submission/payment, child isolation |
| Production simulator package | Upgrade install retained ledger | All 16 tables and 30 historical entries per device preserved row-for-row |
| Orientation/windows | iPhone portrait/both landscapes and four iPad orientations passed | Native rotation retained unfinished form and current page |
| Actual iPad split view | 1210 -> 600 -> 1210 pt passed | Side-by-side Safari then full screen retained input; divider dragging not checked |
| System Reduce Motion | Both simulators passed 0 -> 1 -> 0 | Decorative bobbing stopped, active walking/footprints and restored position retained |
| iPhone 12 / iOS 18.7.7 and iPad mini 6 / iPadOS 18.3.2 | Four physical-device XCTest checks each | Synthetic isolated entry/database/credentials; submission, check, payment, child isolation, restart, specified semantics audit |
| Physical production Release | Signing, installation, process startup passed | Production main restored afterward; all 16 production tables retained row-for-row |
| Additional physical production-main rotation | Not executed | Waiting was cancelled after relocking; neither a pass nor a failure |

Each physical test ledger ended with child one at 200 cents and child two at zero, exactly one income entry and one paid task, and valid integrity/foreign keys. The synthetic initialization entry differs from production zero-onboarding. These four checks are neither full production-main acceptance nor cross-device synchronization.

## Reproducible test entries

`test/` contains rule, database, and widget tests. Wish integration entries are `integration_test/wishboard_test.dart`, `wishboard_restart_test.dart`, and `wishboard_finance_test.dart`. Family/recovery entries are `family_release_test.dart` and `family_release_restart_test.dart`. They use isolated databases and Keychain prefixes; never clear the production database.

See [README](../README.md) for running. Keep `--keep-app-running` when using `flutter drive`: its default cleanup may uninstall the app. Restore `lib/main.dart` after integration testing. Legacy finance acceptance now calls the shared journal journey with its original real/demo isolation assertions. The former flow/restart and internal scene tests use isolated verification files; scene testing mounts the retained harness directly. No production town route is exposed. The required family flow also runs deposits, both dividend choices, active installment/payoff, withdrawals, hypotheses and an independent finance restart.

## Pending

Real CloudKit round trips: zero. Sync, device authorization, out-of-order/conflict handling, and multiple-parent writes are unimplemented. Human VoiceOver reading/gestures, full physical backup/finance/windows, iPadOS 26, energy/performance, and longitudinal child use remain unverified. No TestFlight/App Store release. See [delivery checklist](12-delivery-checklist.md).
