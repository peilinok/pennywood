# 0002: Shared family terms and real-money teaching investments

Status: Accepted
Date: 2026-11-02
Feature IDs: FAMILY-002, TASK-002, INVEST-001, INVEST-002, INVEST-003, AUTH-001, DATA-001, DATA-002, DATA-003, UI-002
Decision owner and approval reference: The product owner requested five experience changes and explicitly selected real pocket money with recorded gains/losses and separate rates for existing products in the 2026-11-02 implementation conversation. Period bounds below are the implementation's disclosed teaching parameters, not exchange or index behavior.

## Context

A nested finance dialog locked the whole parent session on close. Recurring task templates and the single investment rate were child-specific, requiring repeated family configuration. The classroom used static prose, while children need manipulable examples of volatility, distributions, and compounding.

## Options

- Keep investments as a separate virtual-money demonstration. This preserves the old accounting contract but does not satisfy the owner's selected real-money behavior.
- Introduce arbitrary securities, external prices, units/NAV, and unbounded variable returns. This creates dependencies and unfunded parent obligations beyond the local family scope.
- Retain the existing local ledger and fixed plans, adding two bounded teaching-market plans and a separate, read-only animation lesson. This is the chosen bounded change.

## Decision

- Parent authority belongs to the surrounding parent area. Closing its nested finance dialog preserves it. Leaving the parent area, standalone parent-panel exit, profile changes, and inactive/background transitions still revoke authority.
- Store one canonical family recurring-task template per task and one family rate/version per existing fixed product. Keep every child's tasks, payment records, holdings, budget, consent, and ledger independent. Temporary tasks remain child-specific.
- Existing products retain 90-day sapling, 365-day annual, and 30-day fixed dividend terms. Real families start with zero rates. Changing one product only increments that product's version; no existing position rate changes. Changed-and-reverted dividend terms still stop automatic renewal.
- Add 30-day low-volatility dividend and growth/high-volatility teaching plans, minimum CNY 10. These use real pocket money but no securities, banking, payment, or index-data integration. A parent grants/revokes consent separately for each child at the service boundary. Revocation prevents new positions; existing promises and redemption rights survive.
- Low-volatility period value stays between 90% and 105% of principal; growth between 50% and 120%. Reserve the rounded maximum gain before accepting principal. Both return principal plus the signed realized result to cash on maturity or early redemption. New variable plans do not automatically renew. Fixed dividend cash/reinvestment behavior remains available.
- Market model version 1 is a deterministic calendar-based, upward-drift process with declines and occasional shocks. All children see the same daily product movement. Refresh, lessons, replay, and process restart cannot redraw a real position. Version 1 and its rounding must remain available for positions written with terms version 1; a future model requires a new version and reviewed migration.
- During a position, assets retain original principal cost; display current indicative redemption value and unrealized change separately. Only maturity or redemption realizes gains/losses. Reconciliation adds signed realized market return to paid labor and fixed settled yields. Gross positive market payouts consume the child's budget; losses never replenish it or consume another child's funds. Release unused reserved maximum gain at settlement.
- The lesson has independent hypothetical funds/time. Playback, pause/resume, time stepping, random alternative journeys, compounding, and ex-dividend animation never call the accounting service or accelerate real time. Its 5-year trend example is explicitly unbounded and distinct from real 30-day plan limits. Reduced motion immediately reveals the selected result.

## Compatibility and recovery

Schema 6 adds signed return, gross payout, and consent fields to children; family templates and product terms are normalized new tables. Legacy per-child template rows remain for schema/archive compatibility; canonical family templates drive new task instances. Original standards/pay remain in task snapshots and the pre-upgrade copy. Schemas 1-5 upgrade transactionally after the existing before-copy. On migration, the previously active child's future templates/rate initialize family terms. If child rates differed, advance the version beyond existing versions to stop silent dividend renewal. Accepted task and holding snapshots never change. New families seed shared zero/unpaid templates once.

The writer uses authenticated schema6 archives; readers retain original authenticated schema4/schema5 support. Frozen schema5 archives were produced using the baseline writer, not by changing a format label. Restore remains isolated validation followed by a matching-family authorized, encrypted-before-copy transaction. Include the new fields/tables and reconcile signed returns against ledger entries and gross positive payouts. Source fixtures contain only synthetic families.

Older binaries are not supported for schema6 live databases. Preserve an encrypted pre-upgrade archive; prefer forward repair after later transactions. No production reset, Keychain clearing, release tag, merge, or distribution is authorized by this implementation.

## Task contract and validation

Allowed scope: domain rules/models, service/database/backup, wish and finance panels, native lesson, behavior/migration/native tests, and their docs. Preserve all reference accounting cases, permission boundaries, atomicity, child isolation, recovery, and iOS-only targets. No new dependency or platform target.

Acceptance: nested-close regression fails before the fix and passes after; shared templates retain prior task snapshots; independent rates/versions preserve old promises; consent and per-child budget checks reject unsafe entries; signed loss/gain, concurrent purchase, rollback/retry, schema1-5 upgrade, file restart, schema4/5/6 archive round trips, layout, playback, semantics, and reduced motion pass. Run common/secret checks plus disposable iPhone/iPad family and independent restart flows. Physical-device, human VoiceOver, and CloudKit acceptance remain distinct and pending.
