# Accounting Rules and Data Contract

These rules preserve the behavior established in the reference prototype. Follow current user requirements, replay the reference cases, and validate native persistence and permissions separately.

## Accounts and amounts

- Every business record belongs to a family and child. Parents administer accounts; children operate only their own account. UI selection does not replace permission checks.
- Cash is stored as integer cents. Rates use basis points: 100 bps = 1%. Intermediate arithmetic retains sufficient precision; positive amounts round half up to cents at settlement, avoiding floating-point drift and integer overflow.
- Track available cash, held principal, frozen pending withdrawals, delivered withdrawals, settled yields, and repayments separately.
- Account assets = available cash + held principal + pending withdrawals.
- Reconciliation: assets = paid labor income and recorded principal sources + settled yields - delivered withdrawals - repayments.
- A parent funds an advance directly toward a purchase. Its principal never enters the child's wallet, labor income, or investable principal. Purchased objects are outside this teaching account's assets.
- Planned debt includes unpaid principal and agreed future interest. Conservative wish accumulation is assets minus planned debt. This is not general accounting net worth; explain that future interest is included.
- Projections, expected yields, and unperformed future work are not current assets. Distinguish promised unsettled yields from settled cash.

## Real work to income

States: available -> accepted -> submitted by child -> checked by parent -> paid.

Accepting, submitting, and checking do not add money. Only a parent's confirmation of actual delivery or explicitly reserved family custody increases wallet and labor income and creates the corresponding ledger entry. Checking and payment are separate actions. Repeated requests must have no additional effect.

## Teaching plans and budgets

| Plan | Prototype defaults | Settlement |
|---|---|---|
| Sapling term | 90 days, minimum CNY 10 | Principal and yield return to cash; child chooses the next arrangement |
| Annual-ring term | 365 days, minimum CNY 50 | Same; CNY 100 at 3% annually for 365 days earns CNY 3 |
| Town dividend plan | 30-day periods, minimum CNY 10 | Yield follows the cash/reinvestment choice |

These are family teaching parameters, not market quotes. The initial demo rate is 3% annually. A parent must explicitly agree to real terms; each new position snapshots duration, rate, amount, dividend mode, and terms version.

Term yield = principal x agreed annual rate x term days / 365, rounded half up to cents at settlement. Compounding occurs only when settled principal and yield enter a new period.

Early redemption returns full principal. Use actual elapsed days, capped at the term, and the lower of the agreed rate and the example 0.10% annual demand rate. A 0% plan cannot gain 0.10% by redeeming early.

Each child has a separate stage yield budget: available budget = total stage budget - cumulative settled yields - reserved yields of active plans. Check affordability before accepting a new promise. A deposit transfers principal from cash to holdings; it does not create assets.

Lowering a budget cannot consume settled or reserved promises. Rate changes affect only future plans. Withdrawal does not replenish the yield budget. No automatic monthly budget reset has been agreed.

## Dividend allocation and renewal

- Cash dividends add yield to available cash; original principal renews on unchanged terms.
- Reinvestment adds settled yield to next-period principal without also crediting wallet cash.
- Recheck the next period's budget on every renewal. Insufficient budget cannot cancel the current promise; settle it and leave principal/yield in cash.
- If the family has proposed a new rate, settle to cash and wait for the child's renewed acceptance. Never silently substitute terms.
- Changing an active position's next allocation affects future distributions only, not prior settlements or another child.
- Catch up missed periods through the current date, exactly once each. Never book future yields as current money.

The separate fund classroom illustrates ex-dividend accounting: 100 units x NAV 1.03 = CNY 103. Paying CNY 0.03 per unit leaves NAV 1.00. Cash mode holds CNY 100 of units plus CNY 3 cash; reinvestment holds 103 units x 1.00 = CNY 103. Total assets are equal at distribution. The classroom never spends real labor principal.

## Advances, parent interest, and monthly repayments

States: child request -> parent final offer -> child acceptance -> awaiting actual funding -> active -> repaid. Rejection and cancellation create no debt.

Prototype limits are CNY 1-1,000, 1-12 months, and 0%-12% annually. These may remain first-release teaching limits, clearly labeled as family terms rather than market quotes. An advance activates only after actual parent funding, exactly once.

Use equal principal and monthly simple interest:

- Divide principal into integer cents; assign the remainder to the final installment.
- Period interest = opening unpaid principal x annual rate / 12, rounded half up to cents per period.
- Example: CNY 60 over three months at 6% annual interest has CNY 20 principal installments and payments of 20.30, 20.20, and 20.10, totaling CNY 60.60.
- After the due date, the child actively confirms one payment from available cash. Ordinary monthly payment is unavailable before its due date.
- No automatic debits, penalties, interest on interest, negative cash, or partial debits on insufficient cash.
- Early payoff pays all unpaid principal plus due unpaid interest, waiving future installment interest. Do not invent daily accrual for future installments.
- Cash dividends do not automatically repay debt. The child can choose repayment after settlement. Repayments do not consume the parent's yield budget.
- Active terms are fixed; changing the family's investment rate cannot alter an existing advance.
- Calculate monthly dates from the original agreed day. Clamp to month-end where necessary, then restore the original day in later months. Cover leap years, the 31st, and year boundaries.

## Withdrawals

A request moves available cash to pending withdrawal, still within account assets. Only confirmed actual delivery reduces assets and records withdrawal. Repeated delivery cannot debit again. Redeem held principal under its product rules first.

## Persistence and calendar

Commit wallet, holdings, budget, ledger, repayment, and state changes in one database transaction. Use unique operation IDs and settlement-period constraints for repeated taps and retries. Failure must not leave half an operation. The memory-only reference cannot provide these guarantees.

Inject business dates through a replaceable clock using the family's local calendar. Both children share the current family date but settle independently. Check due items on open/resume; do not rely on game frames or continuous background timers. Date acceleration is restricted to isolated demo/development use.

Reference: [26 golden cases](../reference/finance-golden-cases.json) and [prototype rules](../reference/prototype-source/state.js). `test/golden_cases_test.dart` checks the JSON inputs and expected results. Having a case file is not proof that tests ran. Validate prototype limits and date samples explicitly in native rules.
