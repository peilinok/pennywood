# Contributing and AI Work Contract

Use this contract for both human and AI changes. Repository material and Git metadata are English; product copy and Chinese business inputs stay Chinese. Read [AGENTS.md](AGENTS.md) and the relevant product rules first.

## One task, one pull request

1. Check the working tree and remote state. Preserve unrelated edits. Branch from current `main` using `feat/`, `fix/`, `chore/`, or `docs/` plus a short English description. Use a separate worktree only when isolation is needed.
2. Write a short task contract using the template below. Identify affected feature IDs from the [regression matrix](docs/23-feature-regression-matrix.md), acceptance criteria, data risks, and out-of-scope work.
3. Read the implementation and existing tests. Run the relevant baseline checks. For a defect, reproduce it with a failing behavioral test before fixing it.
4. Make the smallest complete change. Keep UI/Flame, business rules, and persistence within their [boundaries](docs/05-architecture-and-storage.md). Do not replace the architecture or delete features to simplify a task.
5. Run `./scripts/check.sh` and the relevant native checks. Review the full diff, staged blobs, privacy, migrations, and evidence. Update the matrix, user guide, and changelog when behavior changes.
6. Push the branch and open a PR using the repository template. Every subsequent commit reruns CI. Do not substitute an AI statement for check results.
7. Merge only when required checks pass on the current candidate and the task authorizes merging. Otherwise leave a reviewable PR. A solo maintainer may self-review; a second account is not required. Squash with an English title and body, then remove the feature branch.

Do not routinely commit to `main`, force-push, delete release tags, rewrite published history, or use `reset --hard`/`clean` to discard work. A rollback uses a new revert/fix PR. Never bypass failed checks with administrator privileges. The initial English-history replacement was an explicitly authorized exception, not the normal workflow.

## Task contract

```text
Goal and user-visible result:
Allowed files/modules:
Protected feature IDs and invariants:
Acceptance examples (including failure/retry behavior):
Schema/backup/permission changes and recovery plan:
Required checks and device evidence:
Out of scope:
Delivery target: local changes / PR / authorized merge
```

An AI may inspect, implement, test, and prepare reviewable changes within the requested scope. Changes to accounting promises, parent permissions, storage compatibility, public-data boundaries, platform scope, or release distribution require an explicit product decision; record a substantial decision in an [ADR](docs/adr/README.md). An existing user decision is authorization: do not ask for it again.

## Definition of done

- Acceptance criteria work end to end; failure paths do not corrupt state or imply a successful save.
- Relevant feature IDs retain meaningful assertions. Never remove a test, weaken an expectation, skip a failure, or update a fixture merely to make CI green. Explain an intentional contract change and retain the old regression where applicable.
- Format, analysis, host/tooling tests, publication/history checks, and secret scanning pass. Required iOS simulator checks pass independently. [Test standards](docs/26-code-and-test-standards.md) define extra checks by risk.
- Database and backup compatibility, restart behavior, permission boundaries, and rollback limits are stated in the PR. Use synthetic data and isolated credentials for tests.
- Documentation matches actual behavior. Separate host tests, simulator build/runtime, and physical-device results; mark pending checks honestly.
- All public paths and metadata are reviewed under the [privacy policy](docs/22-publication-and-privacy.md). Add new paths to both allowlists deliberately; never use `git add -f`.

## Local commands

```sh
./scripts/check.sh
PENNYWOOD_GITLEAKS=YOUR_GITLEAKS_EXECUTABLE ./scripts/check-secrets.sh
python3 scripts/check-publication.py --staged
./scripts/check-ios.sh
```

`check.sh` requires Flutter 3.35.7, Python 3, and Node.js, and checks tracked work plus all locally reachable commits. `check-secrets.sh` requires gitleaks 8.30.1. `check-ios.sh` requires macOS/Xcode and creates disposable iPhone/iPad simulators; it never runs against a supplied physical device or existing family ledger. See [versioning and release](docs/24-versioning-and-release.md) before tagging or distributing an app.
