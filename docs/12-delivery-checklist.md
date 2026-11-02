# Family Release Checklist

Source 0.3.6+10 / schema 5, 2026-11-02. Local use is available; a complete cross-device family release is not delivered. Historical device results are not fresh validation.

| Requirement | Status | Evidence and remaining scope |
|---|---|---|
| Zero onboarding, two children, withdraw/rework/pay once | Implemented; host/simulator verified | Real family has no fixed passcode/balance; 0.3.5 physical core subset passed |
| Wish lifecycle and separate savings/receipt/debt | Implemented; rules/widgets/integration checked | Multiple withdrawals/advances, no payment reuse |
| Edit/pause task agreements and retain history | Implemented | New standards/pay cannot overwrite old snapshots |
| Investments/dividends/budgets/advances/installments/withdrawals | Implemented; rules and earlier simulator integration | 26 cases; not complete current physical regression |
| Schema 1-4 to 5, restart, transactions, idempotency | Implemented and tested | Normalized storage, pre-migration snapshots, historical 16 tables/ledger retained |
| Encrypted backup/recovery, passcode changes, recovery code | Implemented and tested | Wrong password/tampering rejected; pre-restore copy; no credential cloning |
| 0.3.6 secret protection and recovery copy | Fixed | Regressions failed before repair; final suite passed |
| Orientations, themes, large text, reduced motion | Widget and historical system evidence | Full physical windows/directions/accessibility pending |
| Real minimal CloudKit round trip | Incomplete; zero passed | Eligible iCloud team, container, real same-account devices needed |
| Production sync, device authorization, account switching | Unimplemented | Shared Apple Account is not parent permission |
| Offline/duplicate/out-of-order and multiple-parent conflicts | Sync unimplemented | Local idempotency does not verify a cloud protocol |
| Physical installation and local core loop | Historical 0.3.5 passed on two devices | Not repeated on physical devices for 0.3.6 |
| Source, locks, instructions, publication checks | Published scope | Reviewed files only; raw device data and ledger excluded |
| Human VoiceOver, iPadOS 26, long-term child testing | Pending | System audits, simulator sizes, and browser previews are insufficient |
| TestFlight / App Store | Not released | Source publication only |

Next: real CloudKit round trip -> authorization/sync protocol -> submit/check/pay/receive loop -> all monetary operations, multiple-parent conflicts, offline recovery -> physical/long-term acceptance. No custom backend or parallel nearby-transfer implementation. Do not maintain the same family ledger in two independently writable device copies today.

See [validation](10-native-validation.md), [sanitized summary](../evidence/public/validation-summary.json), and [review](21-project-review.md).
