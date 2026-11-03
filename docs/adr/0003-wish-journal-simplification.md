# 0003: One wish-journal workflow

Status: Accepted
Date: 2026-11-03
Feature IDs: UI-001, UI-002, UI-003, UI-004, SCENE-001, TASK-001, TASK-002, AUTH-001
Decision owner and approval reference: The owner requested implementing every task derived from the 2026-11-03 simplification proposal, in order under the project delivery contract.

## Context

The journal and optional town expose overlapping task, wish, money, and parent workflows with different names and capabilities. The wish page repeats both the task grid and task navigation. Finance and parent actions require intermediate overview dialogs; wishes accumulate nested dialogs.

## Options

- Combine wishes and tasks into one destination and retain money as a second destination. This keeps submission on the first screen but mixes feedback, pending tasks, and history into a long wish page.
- Keep three focused destinations and consolidate each business workflow. This adds a tab switch when submitting from wishes but gives tasks and money stable homes. This is chosen.
- Keep a second town-based business UI. This preserves walking but requires maintaining duplicate navigation and business panels without demonstrated child-learning value.

## Decision

- Children have wishes, tasks, and money destinations. A contextual feedback link may target one concrete task; generic duplicate home navigation and task grids are removed.
- Wishes use sequential list/detail/edit navigation. Money has direct withdrawal, one ledger, grouped products, current holdings/debt, and a single read-only learning entry.
- Parent destinations are pending work, the selected child, and shared family settings. Checking and actual payment remain separate; budgets and market permission remain child-specific; agreements and fixed-product rates remain shared.
- Retire the production town entry and duplicate town business panels after their journal replacements work. Keep existing scene data, archive compatibility, source assets, and internal navigation/lifecycle tests. SCENE-001 is deliberately superseded as a production-navigation contract by UI-004 at that stage; never silently remove its matrix row or historical assertions.
- Retain picture-book assets, the mascot, tree/dividend motion, accessible playback, and reduced motion. Do not introduce a new game or change financial rules.
- Move appearance to More, default to the system theme, and keep a labeled parent entry. A returning real family may open directly into the child journal; demo families remain explicit and separate.

## Consequences

The standalone walk, footprints, day/night controls, and camera are no longer production features after retirement. This is an intentional product replacement, not a test workaround. Child usability, human VoiceOver, and physical system window behavior still require human evaluation; a simpler hierarchy does not prove those outcomes.

## Validation and recovery

See the [task plan](../27-interface-simplification.md) for bounded scopes, ownership, acceptance, and evidence. No schema/archive change, balance reset, dependency/platform expansion, parent-capability expansion, or changed holding/task promise is authorized. Use forward UI fixes; preserve schema6 data and authenticated schema4/5/6 readers. Merge and distribution still require their applicable authorization.
