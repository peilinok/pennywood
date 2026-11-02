# Pennywood Working Agreement

## Language and scope

- Use English for repository documentation, code comments, test descriptions, development-tool output, file names, and all Git commit subjects and bodies. Communicate with the user in their preferred language.
- Keep the product UI, Chinese brand, and Chinese business inputs in Simplified Chinese. Do not translate runtime copy or change persisted business data as part of repository-language maintenance.
- Pennywood is a family financial-learning app for children aged 7-10 and their parents.
- Use Flutter + Flame, pure Dart business rules, and SQLite / Drift.
- This release targets iPhone and iPad only. Do not create, develop, or validate Android, Web, macOS, or Windows targets.
- The child entry is the wish journal: wishes, tasks, and pocket money. The Flame town remains an optional walk. The same app provides a parent area and separate child profiles.
- iPhone adapts to portrait and both landscape orientations. iPad supports all four orientations and window resizing. Choose a sidebar or bottom navigation from available width and height; preserve page, form, character, and ledger state during layout changes.
- Current user instructions and docs 08-11 define the product direction. Accounting follows [docs 02](docs/02-accounting-rules.md). Earlier landscape-town home designs and historical prototypes are background only.

## Before implementation

- Read the relevant implementation, dependencies, tests, and product rules before editing. Preserve existing user changes.
- Reuse the existing iOS Flutter project. Create one only if absent, retaining starter materials.
- For multi-step work, state a brief plan and assumptions, then perform authorized local work.
- Keep changes focused. Do not add unrelated refactors, frameworks, dependencies, services, game editors, or event-sourcing infrastructure.
- Deliver a working end-to-end path before expanding the feature set. Explain any new dependency.

## Business and presentation invariants

- Real-world work earns income only after a parent checks it and confirms actual payment or explicitly reserved custody. Exploration never pays money.
- Parents fund agreed yields. Budgets are separate per child; new rates or lower budgets cannot replace existing promises.
- Follow [accounting rules](docs/02-accounting-rules.md) for cash dividends, reinvestment, advances, and repayments.
- Keep cash, holdings, frozen withdrawals, debt, and projections separate. Never mix children's accounts.
- Validate permissions and amounts at the business entry. Save related state, ledger entries, and unique operation IDs in one transaction. Show success only after persistence.
- HTML, SVG, and JavaScript are design/behavior references, not the production accounting implementation. Use native Flutter / Flame UI.
- Follow [the design system](design-system/pennywood/MASTER.md) for the wish journal and [scene guidance](docs/04-art-and-scene.md) for the optional town.
- Real families start with zero balances. Demo families are separate; demo passcodes must never become production credentials.

## Verification and publication

- Reproduce defects before fixing them; add behavior-based regressions. Do not add tests that merely restate implementation.
- Maintain Dart coverage for reference accounting cases, transactions, persistence, restarts, permissions, and date boundaries.
- Run checks appropriate to the change. Investigate failures before editing; do not expand passing checks without a reason.
- Report static analysis, automated tests, simulator build, simulator runtime, and physical-device validation separately. Label unverified items explicitly.
- Keep current implementation evidence separate from browser reference evidence. Publish only sanitized summaries in `evidence/public/`.
- Update README run instructions and delivery status. Use repository-relative evidence links, never personal machine paths.
- Review actual staged blobs and complete reachable history before publishing. Keep databases, backups, device identifiers, raw logs/screenshots, signing data, and private archives local. Use GitHub noreply commit identities.

## AI delivery contract

- Follow [CONTRIBUTING.md](CONTRIBUTING.md) for every task. State the goal, allowed scope, protected feature IDs, acceptance checks, and data/recovery implications before implementation.
- Use one short-lived branch and PR per bounded task. Preserve the [regression matrix](docs/23-feature-regression-matrix.md); never remove features, weaken assertions, or skip failures just to pass checks.
- Run `./scripts/check.sh`, default-rule secret scanning, and the relevant native checks. Required CI results belong to the current candidate, not an earlier commit.
- Follow [code/test standards](docs/26-code-and-test-standards.md), [release rules](docs/24-versioning-and-release.md), and [data recovery](docs/25-data-compatibility-and-recovery.md). Record lasting decisions in [ADRs](docs/adr/README.md).
- No routine force pushes, published-history rewrites, tag replacement, database resets, or production Keychain clearing. Use new revert/fix PRs; prefer forward repair after an incompatible data upgrade.
- Merge/distribute only within the user's authorization. An existing authorization need not be requested again. Report remaining acceptance gaps rather than claiming an unverified release.
