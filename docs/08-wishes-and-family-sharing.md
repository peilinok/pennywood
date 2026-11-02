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

## Cross-device plan: not implemented

Target use: parent iPhone/iPad and child iPad on the same Apple Account. The candidate is local Drift plus CloudKit private database, without a custom backend. Apple hosts the service; record sync, authorization, and accounting consistency still require implementation.

One Apple Account identifies one cloud user, not a parent. Device admission and parent-device approval need explicit design. CloudKit does not automatically isolate child/parent roles within that account. Do not assume local unlock credentials follow ledger sync.

Planned loop: child submission -> local pending upload -> parent receives -> parent checks/confirms payment -> transactional posting and upload -> child receives once -> wish updates. Distinguish saved, sending, delivered, confirmed, and failed states. Do not display money before the confirmed result arrives.

Handle stable operation IDs, per-child write ordering, duplicates/out-of-order delivery, conflicts, offline unknown results, deletion/archive, restore, and account changes. Do not overwrite final balances or share a live SQLite file via iCloud Drive. Do not silently require a permanently online primary device.

First validate eligible signing/container and bidirectional synthetic records with offline retries on two physical devices, then define production protocol/schema. A free Personal Team lacks the required iCloud entitlement; verified real cloud round trips remain zero. Keep iOS 13 minimum unless explicitly changed; CKSyncEngine requires iOS 17.

Cross-account sharing, Bluetooth/nearby transfer, payments, and financial accounts are outside this implementation. See [technical research](research/2026-11-01-serverless-family-sync.md) for official sources, quotas, and OS boundaries.
