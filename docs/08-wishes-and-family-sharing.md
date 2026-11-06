# Wishes and Family Sharing

The production entry is a native Flutter wish journal backed by local Drift accounting. This document distinguishes current local behavior from planned cross-device sharing. HTML prototypes support interaction discussion only.

## Wishes and actions

Children choose one primary wish and queue the rest. Gift wishes record savings and actual receipt separately; savings goals use confirmed accumulation. Editing, deletion/archive, and primary selection use the business entry. Preserve payment-linked history: linked wishes cannot be deleted or changed to another type.

Real work, proactive learning, and temporary tasks require an agreed standard and payment first. Dishes, mopping, toys, vegetable preparation, and learning submit with one tap; complex temporary tasks require acceptance. Submission/checking never credits income. Parents must confirm actual payment or reserved custody. Before checking, accidental submissions can be withdrawn. Specific feedback supports resubmission. New standards/rates do not replace old task snapshots.

Investments arrange existing cash and use parent-funded, budgeted yields. Advances require the child's acceptance of final terms and actual parent funding; they do not increase wallet or labor income. Gift receipt may combine several delivered withdrawals and funded principal amounts, with exact purchase-cost equality and no payment reuse. Debt survives gift receipt.

Wishes, tasks, cash, holdings, budgets, dividends, loans, repayments, and scene state are independent per child. One accumulation serves one primary wish. See [accounting rules](02-accounting-rules.md).

## Current local mode

One app contains child and parent areas sharing a local ledger. Parent credential/recovery data stays in local Keychain. Leaving parent space, switching child, or leaving the foreground relocks access. Secret forms clear and conceal secrets on leaving the foreground; ordinary input remains.

Real families start at zero. Demo families use separate credentials and synthetic principal/tasks. There is no production default passcode. Authenticated encrypted archives can be manually restored on another device; recovery returns to the snapshot and does not merge later edits.

## Cross-device plan: accepted direction, not implemented

The owner selected one-time custom particle camera pairing and foreground nearby Wi-Fi synchronization: after pairing, both ends tap Sync and discover/authenticate each other automatically. A common Apple Account, internet server, routine rescanning and ordinary manual Wi-Fi switching are not part of the intended experience. See [ADR 0004](adr/0004-nearby-family-sync.md), the [custom optical decision](adr/0005-custom-particle-pairing.md) and the [complete implementation plan](28-nearby-family-sync-plan.md).

One primary accounting device admits peers and commits financial state. Companions receive only granted children and submit permitted intents or view confirmed information. The primary may be offline; requests wait until the next nearby session. A companion never gains parent payment authority by sharing a local passcode, and it never runs financial catch-up independently.

Planned loop: child saves a pending request -> both ends tap Sync -> primary receives -> parent checks and confirms actual payment -> transactional posting -> child receives the confirmed result once. A bounded foreground session can deliver new results while the parent reviews. Distinguish locally saved, delivered, needing attention, and posted states.

Keep stable operation IDs, ordered requests, durable acknowledgments, scope checks, original promises, safe archive recovery and generation changes. Do not merge independently writable SQLite copies or overwrite balances using arrival order. The implementation remains subject to actual camera/radio, permission, security and two-device acceptance; keep iOS 13 unless explicitly changed.

CloudKit is deferred from the first route, along with BLE/acoustic fallback, independent financial writers and continuous background sync. The [earlier cloud study](research/2026-11-01-serverless-family-sync.md) remains research, with zero verified Pennywood CloudKit round trips. Payments, banking and financial-account integrations remain outside scope.
