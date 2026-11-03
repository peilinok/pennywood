# Interface Simplification Delivery Plan

Date: 2026-11-03. Baseline: 0.4.0+11, schema6, merged PR #2. Product decision: [ADR 0003](adr/0003-wish-journal-simplification.md). The owner authorized completing all tasks below. This is an implementation plan, not evidence that pending work passed.

## Shared contract

Goal: one complete native journal workflow with fewer duplicate controls and predictable returns. Keep the accounting service, separate children, original promises, real payment gates, date/idempotency behavior, archive readers, and credentials. No schema change, new dependency, platform target, real-family test fixture, reset, or release distribution. Presentation-only work retains schema6 and archive compatibility; forward fixes are the recovery path.

Each task gets a short-lived branch and PR, common checks, default-rule secret scanning, staged/history review, and relevant iPhone/iPad simulator journeys. Preserve meaningful existing assertions when adapting navigation. Record exact candidate CI in each PR. Do not treat prior device evidence as current. Human child/VoiceOver evaluation and physical iPadOS windowing remain separate acceptance.

## Tasks

| Task | Bounded scope and visible result | Protected IDs | Acceptance and evidence | Status |
|---|---|---|---|---|
| S1 Child navigation and tasks | `wish_home.dart`, behavior/native tests, related docs: focused wish home, one full task area, configured/pending task visibility, state-specific actions, one contextual feedback link, separate retained page scroll | TASK-001/002, DATE-001, AUTH-001, UI-001/002/004 | Home has no duplicate task grid/generic task/finance navigation; task submit/withdraw/rework never credits income; paused pending/cross-day tasks remain actionable; page/child/reflow state retained | In progress |
| S2 Sequential wish navigation | Wish list/detail/editor/receipt routes and related tests/docs: tappable primary card, other wishes, no dead child receipt action, contextual gift advance | WISH-001/002, LOAN-001, AUTH-001/002, UI-001/002/004 | Edit/validation/reflow/history/receipt links and debt preserved; back returns to list/detail; child receipt is explanatory; a new advance starts from its gift wish | Pending |
| S3 Money and learning | Money overview and finance/lesson UI plus related tests/docs: direct withdrawal; principal/holdings/frozen/debt separation; recent/full filtered ledger; five grouped products; one deposit confirmation with live amount/risk summary; one learning entry; current debt/holding summaries | MONEY-001, INVEST-001/002/003, LOAN-001/002, DATA-001, UI-001/002/003/004 | Withdrawal opens its form directly; invalid purchase preserves input; all five plans/old promises accessible; existing revoked-consent holdings redeem; repayment/early redemption/loan acceptance keep amount confirmations; projections remain hypothetical | Pending |
| S4 Parent responsibilities | Pending/child/family UI and related tests/docs: direct actionable work, child budget/permission/name, shared rates/tasks, one profile switch, one task creation entry, backup/recovery | FAMILY-002, TASK-001/002, INVEST-002/003, AUTH-001/002, DATA-001/003, UI-001/002/004 | Direct check/pay/handover/offer/fund; waiting-for-child is not actionable parent work; independent budgets/permission and shared rates; close retains session, switch/background/exit locks; recovery reachable | Pending |
| S5 Town retirement and daily-entry polish | Production route removal, old panel consolidation, appearance/startup/copy, regression/docs and final native journey: one business UI, system appearance under More, labeled parent entry, return to real journal | FAMILY-001/002, AUTH-001/002, DATA-002/003, UI-001/002/003/004; explicitly supersede SCENE-001 production entry | No production town/duplicate task/wish/wallet/parent/growth panels; assets/data/internal scene tests retained; only real-family automatic entry, demo explicit; all workflows survive reflow/restart; complete final audit | Pending |

Sequential dependencies: S1 -> S2 -> S3 -> S4 -> S5. Start each next task from integrated main when merging is authorized. A reviewable dependent PR may temporarily target its predecessor while awaiting authorization; do not silently include unrelated prerequisite changes in its diff.

## Proposal coverage

| Proposal item | Task |
|---|---|
| Three focused child destinations; remove wish-page grid and duplicate task/invest/advance cards | S1 |
| Contextual feedback; configured templates; direct task actions; cross-day pending/history | S1 |
| Primary-card entry; other wishes; sequential list/detail/edit; parent-only real receipt | S2 |
| New advance from a gift wish; current advances/repayment retained in money | S2, S3 |
| Direct withdrawal; one primary balance; visible nonzero frozen/debt; holding/debt summaries | S3 |
| One recent/full ledger with classification; one learning entry; actual versus hypothetical returns | S3 |
| Five products grouped by fixed/variable; amount-specific single deposit confirmation | S3 |
| Pending work/child/shared settings; direct parent operations; no mixed overview detour | S4 |
| Child-specific budgets/consent; separate child-name form; one profile/task-create entry | S4 |
| Family-wide rates/tasks; backup/passcode/recovery remain reachable | S4 |
| Standalone town retirement and SCENE-001 replacement; preserve data and expressive assets | S5 |
| Consistent wish/money labels; concise introductions; meaningful save/error feedback | S5 |
| Appearance under More, system default, labeled parent entry; returning real-family startup | S5 |
| Safe financial confirmations, no promise/schema/credential change, retained forms/pages/scroll/lesson, touch/semantics/themes/windowing | Every affected task; final audit in S5 |
| Five real-child scenarios: submit, find feedback, identify actual payment, request withdrawal, find next repayment | Human acceptance after implementation; not replaceable by automated tests |

## Baseline and delivery record

- 2026-11-03: baseline `./scripts/check.sh` passed (118 host tests, all 26 accounting cases, analysis/tooling/privacy/history checks); default gitleaks 8.30.1 scans passed. PR #2 had passing exact-head required CI and was merged with explicit owner authorization as `60b0247`.
- S1 onward: add durable PR/check links as each bounded task becomes reviewable. No physical-device or human-learning claim is implied by this plan.
