# Wish Journal UI / UX

Six production pages use Flutter/Drift. Local UI does not display fake cloud delivery/receipt. HTML send/receive tools are prototype controls only.

## Navigation and hierarchy

| Role | Page | Content |
|---|---|---|
| Child | My wishes | Primary wish, confirmed accumulation, target/gap, queue, at most one concrete rework hint |
| Child | My tasks | Accept/submit, waiting, withdraw, feedback, resubmit, history |
| Child | My pocket money | One available balance, nonzero principal/frozen/debt, direct withdrawal and holding/advance records, grouped plans, classified ledger and one classroom |
| Parent | Pending | Selected child, direct checking/payment, withdrawal handover, advance offers/funding; child-waiting offers are read-only |
| Parent | Child | Wishes/receipts, ledger, independent budget/consent, separate profile name and one temporary-task creation entry |
| Parent | Family | Shared task standards/payment, pause/edit, independent product rates, backups/passcodes/recovery |

Each role has three main destinations. Use a sidebar when both dimensions allow it; otherwise use bottom navigation, including short windows and large text. Do not shrink an iPad canvas to fit a phone. More contains Appearance and an explicit return to family entry. Default appearance follows the system; light/dark overrides are available. Returning real families enter the selected child automatically once; demos stay explicit. The production town entry is retired by ADR 0003.

## Frequent child actions

Finish real work -> tap the whole dishes/mopping/toys/vegetables/learning card -> wait for parent checking. Withdraw before checking. Repeated taps show state rather than creating income. Allow at most one instance per child/template/day; preserve pending instances across dates.

The complete task area lives in Tasks. Show configured recurring agreements and existing instances, including paused or prior-day promises; unconfigured templates use a shared empty state. Accepted temporary tasks can submit directly from their cards. Each child/role/destination retains its own scroll context. The wish home has no generic duplicate task, investment, or advance navigation; a concrete feedback hint may open its exact task.

New wishes specify type, name, and amount. Validation preserves input. Gift and savings goals have different meanings. Queued wishes do not copy balances. Expected returns and advances never fill savings progress. Choose the next primary wish explicitly.

The complete primary card opens its detail page while the monetary summary keeps independent semantics. Other wishes -> detail -> edit uses sequential pages; saving/cancelling returns to the originating detail/list, not the home. Gift receipt is a parent-only page; children see an explanation and can propose an explicitly linked advance from the gift detail. Existing loans and all final-condition/funding rules remain unchanged.

Feedback highlights specific effort and actual changes. No streak resets, leaderboards, expiring rewards, or coin floods. Long-term child preference still needs real testing.

## Parent confirmation

Show child, original standard, and payment. A parent checks or gives specific feedback first. Then require explicit confirmation of actual delivery/reserved custody before enabling payment. Update cash/wish only after saving. No bulk one-tap payment.

Present saving enough, receiving the gift, and repaying debt separately. Explain deposits as cash-to-holdings transfers and withdrawal requests as frozen cash; only actual delivery reduces assets. Explain planned debt's future-interest component.

## Visuals and accessibility

Follow the [design system](../design-system/pennywood/MASTER.md): paper, charcoal, chestnut, grass green, and wheat for payment. Preserve squirrel, telescope, tree, and task-art colors rather than assigning each card a pastel background.

Pair functional icons with text/semantics; never encode posting state only in color. Read monetary purpose and amount together, and read wish accumulation/target/progress. Name the page scroll region while retaining independent buttons. Minimum targets are 44 pt. Support safe areas, vertical scrolling, light/dark themes, scalable text, and reduced decorative motion without disabling saving. Internal walking tests remain preserved independently.

Orientation, window, and keyboard changes retain child, page, ordinary input, and ledger. Backgrounding clears secret fields for credential protection. See [native validation](10-native-validation.md) and [adaptive validation](11-adaptive-layout-validation.md). Browser/widget sizes do not prove human VoiceOver usability.

## Prototype boundary

[Wish prototype source](../prototype/wishboard/) rebuilds with Python's standard library. Device/role selection, large-text previews, and delivery buttons are design tools. Demo families/balances are synthetic and never connect to production SQLite or Keychain. The native child UI does not use a WebView.
