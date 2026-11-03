# User Guide, Backup, and Recovery

The app's labels remain in Simplified Chinese. The English names below describe their meaning.

## First day

1. Choose Create our family / Start from zero. Enter two child names and a 6-12 digit parent passcode. Real balances, budget, and rate start at zero; no default paid tasks or wishes exist.
2. Create a gift wish or savings goal. Choose one primary wish and queue the rest.
3. Unlock the parent area. In Family agreements, set family-wide standards/pay once for all children or agree on a temporary task. Agree first, perform real work afterward.
4. After finishing, the child opens Tasks and taps the agreed recurring task, or directly submits an accepted temporary task. Withdraw before checking if needed. Read specific feedback and resubmit after improvement; the wish home can point to one concrete reminder. Paused agreements retain existing instances, including prior-day pending work.
5. The parent checks, then separately confirms actual delivery or reserved custody and pays. Only now are cash and wish progress credited.
6. Children have independent tasks, wishes, and ledgers. Leaving parent space, switching child, or leaving the foreground relocks access and clears secret form input.

Demo families contain synthetic funds/tasks and require a separate passcode. They never populate real families. Only local storage exists today; a shared Apple Account does not synchronize it. Choose one device for the production ledger.

## Finance, advances, and gifts

Money emphasizes available pocket money. Nonzero held principal, frozen withdrawals, and planned debt stay visible separately; expand Account details for totals and zero balances. Tap a holding for its original terms and early redemption, including when new market permission has been disabled. Tap an advance for its schedule, next amount/date, acceptance, or active repayment. Historical records remain available.

Request actual withdrawal opens its form directly. Saving freezes cash without reducing assets; actual parent delivery reduces assets. Arrange money groups all five plans into fixed agreements and variable returns. Its amount page updates the expected yield or maximum loss/gain and reservation; one explicit confirmation persists the deposit. Invalid amounts retain the form. The ledger defaults to five recent financial entries and can show all entries or a category, including nonfinancial history.

Deposits move cash to holdings. Parents must agree to yields and fund the budget; expected yield is not present accumulation. Advances activate only after a parent offers final terms, the child accepts, and actual funding occurs. Funds do not enter the child's wallet. Monthly payments are actively chosen after due dates, with no automatic debit or penalty.

A savings milestone does not debit money. A parent verifies gift receipt and links delivered withdrawals and actually funded principal totaling the purchase cost. Do not debit again. Debt remains separate.

Tap the primary wish card to open its detail, or use Other wishes for the queue/history. Editing is a separate page and returns to the same detail. A child can propose an advance from a gift detail with that wish explicitly selected. The parent records actual gift receipt from the parent's wish detail; the child sees the corresponding explanation instead of an action that cannot run.

## Shared terms, investments, and classroom

Family agreements apply to every child; submitted/accepted tasks retain their saved standards and pay. Temporary tasks, real task completions, budgets, wishes, consent, and balances remain child-specific. From Family agreements, open finance management: closing that nested dialog keeps the surrounding parent session unlocked. Profile changes, leaving parent space, and backgrounding still lock it.

Set the 90-day, 365-day, and fixed-dividend annual rates independently under family product rates. Existing holdings retain the originally accepted rate; changed-and-reverted dividend terms require renewed acceptance. Budget/name edits only affect the selected child.

Parents may allow low/high-volatility teaching investments separately for each child. These use real pocket money and may lose principal. Before accepting a position, read its 30-day maximum loss/gain and the child's budget reservation. Indicative redemption values remain separate from cost-based holdings until realization. At maturity or early redemption, gains/losses enter cash and the ledger once. Disabling permission prevents new positions and leaves old promises intact. There is no external fund/Nasdaq trading or guaranteed upward return.

Open Product classroom from Money to play/pause a five-year curve journey, inspect individual months, compare retained/withdrawn yields, and move dividends to a pocket or reinvest them. Lessons never change cash or family time; reduced motion provides direct results. A simulated new journey only changes classroom examples. My hypothesis compares reinvestment and withdrawn yields over 1-20 years, optionally adding 52 weeks of planned labor at each year end. Editing those amounts changes only the lesson. Actual returns stay in the Money ledger.

Upgrade to schema6 installs over the existing app. Shared future templates start from the previously active child; all old task and holding promises stay intact. Export/verify a backup before upgrading; use forward repair rather than installing an older binary on schema6 data.

## Encrypted backup and moving devices

Open Family agreements -> Backup, recovery, and parent passcode. Verify the local passcode again, choose a separate backup password of at least ten characters, and export a `.pennywood` file through the system picker. Archives contain neither parent passcode nor recovery code. Keep the password separately and retain multiple dated copies.

To restore, choose the archive, enter its password, review family/children/time/ledger count, and confirm. An existing family requires the current local credential and matching stable family identity. Save an encrypted pre-restore copy before transactional replacement. Recovery returns to that snapshot; later local changes are not merged. Wrong passwords, tampered ciphertext, and invalid accounting are rejected.

A new device can restore from the welcome screen and sets its own local passcode. Retained Keychain credentials still require their old passcode. Schema4, schema5, and schema6 archives are accepted. Manual iCloud Drive storage is backup, not sync. Continue accounting in only one copy after moving devices.

Uninstalling deletes the local ledger. Upgrade by installing over the existing app. Verify a recoverable backup before uninstalling/moving devices. The live database stays in Application Support and is not exposed through file sharing.

## Passcodes and recovery codes

Verify the old passcode to change it, or generate a recovery code in advance. The code appears once and is concealed on leaving the foreground. Generating a new one invalidates the old. Anyone holding it can reset the local parent passcode: keep it outside the app, away from children.

If the passcode is forgotten, choose Forgot parent passcode on the family home and use the previously saved recovery code. Recovery does not clear the database. No code means no parent-lock bypass. The backup password decrypts archives; the recovery code resets the local passcode. They are not interchangeable.
