# Data Compatibility and Recovery

Protect the ledger before protecting the build. Code rollback and data recovery are separate operations; a Git tag does not save a family's database or Keychain.

## Current compatibility contract

| Item | Supported behavior | Limitation |
|---|---|---|
| Live database | New schema5 databases; explicit upgrades from schemas 1, 2, 3, and 4 | Downgrading a schema5 database to older apps is not supported or validated |
| Migration safety | Consistent `.before-vN.sqlite` copy before upgrading a file database; migration transaction | Private snapshot is not an encrypted portable family backup; protect its location |
| Archive reader | Authenticated encrypted schema4/schema5 archives | Unsupported future formats must not overwrite local data |
| Restore | Validate in isolation, authorize matching family, save an encrypted before-copy, replace transactionally | Snapshot replacement, not merging; later transactions are lost from the active copy |
| Credentials | Local Keychain passcode derivation and separate recovery code | Archive never clones passcodes/recovery codes; changing devices needs local authorization/setup |
| Multi-device use | One authoritative local accounting device | iCloud Drive files are backups; live synchronization is unimplemented |

Keep append-only ledger records, unique operation IDs, original terms, family/child keys, and payment associations through migration and backup. Preserve both children and demo separation. Never reset a database, drop history, regenerate family identity, or clear all Keychain items to recover from an error.

## Required evidence for a schema or archive change

- List every supported starting schema/format and expected target. Retain old synthetic fixtures; add a new one rather than overwriting historical meaning.
- Upgrade realistic synthetic accounts with ledger entries, operations, active holdings/promises, withdrawals, funded loans/installments, wishes/payment links, and two children.
- Verify balances, reconciliation, row relationships, stable identity, operation replay rejection, `foreign_key_check`, and independent close/reopen. Inject a failure and prove rollback and preservation of the original/safety copy.
- Refuse unknown/incompatible inputs safely. Validate archive passwords, header authentication, tampering, wrong-family restore, and safety-copy failure.
- Record whether the previous binary can read the new data. If unproven, the rollback plan is a forward fix, not an older binary. Keep old archive readers until a separately approved retention change.
- Run isolated native migration/restart/restore checks before distribution; host tests alone do not establish device filesystem/Keychain behavior.

## Operational backup policy

This is a manual operating policy; the app does not implement automatic scheduled backups or retention cleanup.

1. Export an encrypted family backup at the end of any day with new transactions and before upgrading, restoring, uninstalling, moving devices, or changing storage/authentication. Verify the selected family's timestamp and ledger count.
2. Retain at least the latest seven daily copies, four weekly copies, and one verified pre-upgrade copy for each of the last three distributed app versions. A copy may satisfy multiple periods. Do not prune the last known-restorable copy or the copy needed for an unresolved incident.
3. Keep two encrypted copies in separate locations, such as iCloud Drive and a private offline location. Do not place them, raw migration snapshots, or passwords inside this repository or public CI. Keep backup passwords and recovery codes separately.
4. Before a release and at least monthly during active use, restore a copy into an isolated test destination. Verify both children's balances, ledger counts, debt, wishes, and duplicate-payment rejection. Record only version/date/pass/fail in public evidence.
5. A file existing or an export succeeding is not a completed restore exercise. Do not delete production data to test a backup.

## Incident procedure

1. Stop writes/distribution and identify app build, schema, family, and last known-good timestamp locally. Preserve the current encrypted export if possible, migration snapshots, and a consistent private database copy; never publish incident contents.
2. Reproduce with sanitized data. Determine whether the issue is UI-only, wrong business logic, failed migration, corrupted storage, or credentials. Do not patch balances manually without a reviewed reconciliation plan.
3. Prefer a forward repair that retains legitimate later ledger entries. If restoring is necessary, show exactly which timestamp will replace current state and obtain the owner's confirmation of the lost interval. Preserve the encrypted pre-restore copy first.
4. Validate the repaired/restored state, both child scopes, ledger/operation consistency, and restart. Resume writes in only the authoritative copy. Keep the incident reproduction as a regression.

The [user guide](13-user-guide-and-recovery.md) describes existing UI. This policy adds release/operating discipline; it does not claim automatic merge, remote recovery, or a parent-lock bypass.
