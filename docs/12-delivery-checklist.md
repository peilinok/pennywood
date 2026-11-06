# Family Release Checklist

Candidate 0.5.0+12 / schema 6, 2026-11-03. See the [bounded simplification delivery plan](27-interface-simplification.md) and [validation summary](../evidence/public/interface-simplification-validation.json) for exact scope and candidate checks. Local use is available; a complete cross-device family release is not delivered. Historical device results are not fresh validation.

| Requirement | Status | Evidence and remaining scope |
|---|---|---|
| Zero onboarding, two children, withdraw/rework/pay once | Implemented; host/simulator verified | Real family has no fixed passcode/balance; 0.3.5 physical core subset passed |
| Wish lifecycle and separate savings/receipt/debt | Implemented; rules/widgets/integration checked | Multiple withdrawals/advances, no payment reuse |
| Edit/pause task agreements and retain history | Implemented | New standards/pay cannot overwrite old snapshots |
| Investments/dividends/budgets/advances/installments/withdrawals | Implemented; host and local iPhone/iPad integration/restart verified | 26 cases; final exact-head hosted checks are in each PR; not complete current physical regression |
| Schema 1-5 to 6, restart, transactions, idempotency | Implemented and tested | Normalized storage, pre-migration snapshots, historical 16 tables/ledger retained |
| Encrypted backup/recovery, passcode changes, recovery code | Implemented and tested | Wrong password/tampering rejected; pre-restore copy; no credential cloning |
| 0.3.6 secret protection and recovery copy | Fixed | Regressions failed before repair; final suite passed |
| Orientations, themes, large text, reduced motion | Widget and historical system evidence | Full physical windows/directions/accessibility pending |
| Custom particle camera pairing and automatic nearby Wi-Fi exchange | Planned under ADR 0004/0005; unimplemented | 18 synthetic optical checks only; native recognition and two-device optical/network/security proof are pending |
| Primary device authority, child-scoped peers, durable requests/receipts and recovery | Unimplemented | See the [nearby plan](28-nearby-family-sync-plan.md); one primary, no independent financial writers |
| CloudKit round trip, account switching and independent-parent conflicts | Deferred; zero real cloud round trips | Earlier cloud research remains separate from nearby acceptance |
| Physical installation and local core loop | Historical 0.3.5 passed on two devices | Not repeated on physical devices for 0.3.6 |
| Source, locks, instructions, publication checks | Published scope | Reviewed files only; raw device data and ledger excluded |
| Human VoiceOver, iPadOS 26, long-term child testing | Pending | System audits, simulator sizes, and browser previews are insufficient |
| TestFlight / App Store | Not released | Source publication only |

Next: native nearby/camera proof -> single-authority storage and pairing -> submit/check/pay/receive loop -> all child/financial requests -> archive/recovery and UI polish -> exact-candidate physical acceptance, following [N1-N7](28-nearby-family-sync-plan.md). No custom backend or parallel BLE/acoustic implementation. Current binaries remain local-only; do not maintain the same family ledger in two independently writable device copies today.

See [validation](10-native-validation.md), [sanitized summary](../evidence/public/validation-summary.json), and [review](21-project-review.md).
