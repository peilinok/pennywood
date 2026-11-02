# Code and Test Standards

## Module and dependency rules

- `lib/domain/`: pure Dart, deterministic money/calendar/business rules. No Flutter, Flame, Drift, platform API, filesystem, wall-clock lookup, UI, or global mutable account state. Receive dates from the injected clock. Use integer cents, basis points, and explicit BigInt rounding, not floating-point cash.
- `lib/data/`: normalized Drift records, parameterized SQL, migrations, authentication, backup validation, and `TownService` as the unified business entry. Validate family/child capabilities here even if UI buttons are hidden. Commit state, ledger, and operation ID atomically.
- `lib/app/` and `lib/features/`: orchestration and native UI. UI never edits balances or calls raw SQL to bypass rules. Await persistence before success feedback. Keep ordinary forms across reflow; conceal/clear secret fields on leaving the foreground.
- `lib/game/`: presentation/navigation and scene persistence through the controller/service. Frames, walking, and exploration cannot mutate money or simulate real settlement time.
- Add a dependency only when existing code/standard libraries cannot meet an actual requirement. Explain maintenance, size, license, platform support, and lockfile changes. Do not upgrade dependencies or create platform targets incidentally.

The lightweight repository-policy check enforces domain imports and generated-platform boundaries. It is not a full architectural proof; review transitive dependencies and business entry usage too.

## Dart and UI conventions

Use `dart format` and the project's `flutter_lints`; analysis warnings/infos fail checks. Follow existing naming and imports, avoid `dynamic` outside bounded serialization/SQL adapters, and preserve explicit return types on public entry points. Handle expected business failures with the existing `RuleViolation` contract. Do not swallow unexpected errors, expose secrets in logs, or report success after a failed save.

Await meaningful asynchronous work. Fire-and-forget work must be deliberate, with a documented owner/error path; do not mask a lint with a broad ignore. Dispose observers, timers, listeners, and controllers according to ownership. Check lifecycle/`mounted` after asynchronous UI work. Do not introduce blanket analyzer exclusions or global ignores to make CI pass.

Comments explain non-obvious constraints and decisions in English. Keep Chinese product copy and business inputs. Tests, tools, and commit messages use descriptive English. Do not reformat unrelated code or refactor a whole module to solve a small task. HTML is a visual/behavior reference; no production WebView accounting.

## Tests by change type

| Change | Required behavior/evidence beyond the common checks |
|---|---|
| Money/date/rules | Independent numeric anchors, conservation, invalid inputs, date boundaries, retries; preserve all 26 golden cases |
| Database/transactions | Failure injection, atomic rollback, duplicate/concurrent operations, file reopen, child ownership |
| Schema/archive | Every supported prior version/fixture, relationships and IDs preserved, snapshot failure, wrong input rejection, native upgrade/restart/restore |
| Parent/auth/secrets | Unauthorized calls at service entry, expiry/switch/background, late unlock, hidden/cleared secrets, credential isolation |
| UI/layout | Interaction and validation, retained ordinary form state, portrait/landscape/window sizes, themes/large text/reduced motion, semantics; affected native journey |
| Flame scene | Navigation/collisions, component lifecycle, saved position, scene entry, no financial side effects |
| Build/CI/privacy tools | Temporary synthetic repositories/fixtures, observe a failing regression first, then test success and failure paths; workflow syntax validation |
| Documentation only | Links, language/privacy/history, consistency with implementation; required CI remains mandatory |

Every bug fix begins with a reproduction. Test observable behavior, not private method order or constructor assignments. Use fixed clocks, in-memory or disposable file databases, separate Keychain prefixes, and controlled failures. Never use a real child's records, production credentials, or production database reset as a fixture. Financial expectations must not merely call the same implementation twice.

All new behavior needs affected [feature IDs](23-feature-regression-matrix.md). If deleting or weakening an existing assertion is necessary for a deliberate product change, explain it in the PR and update the accepted rule explicitly. A fixed test-count threshold is not coverage; retain the actual behaviors.

## Common checks and evidence levels

`./scripts/check.sh` runs locked dependency resolution, format, fatal analysis, the complete host suite, tooling tests, repository boundaries, actual tracked-file privacy, all reachable commit trees/metadata, reference rules/case regeneration, and rebuildable prototypes. It fails if lockfiles change. `./scripts/check-secrets.sh` additionally scans reachable Git history and tracked worktree content using gitleaks 8.30.1 default rules with redacted output. Exact local private-string scans remain an additional publication step; public CI cannot know private values.

`./scripts/check-ios.sh` builds the production entry, then runs the isolated family-release scenario and its restart companion in separate processes on disposable iPhone and iPad simulators. It requires an installed compatible runtime. It does not perform physical-device, CloudKit, complete VoiceOver, or every integration-test acceptance. No raw screenshots or archives are uploaded from CI.

Pass `iPhone` or `iPad` to run only one device family; hosted CI uses both in parallel and requires their aggregate result. A slow cold run is not a failed test. Keep test assertions intact and distinguish an explicit cancellation from a code/runtime failure.

Report baseline failures and final results separately. A delivery names the source SHA, checks run, simulator build, simulator runtime, physical devices, data compatibility, and remaining work. Keep public evidence sanitized and private raw evidence local. Do not call an older physical test a current pass.
