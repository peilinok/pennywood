# 0001: Protected Integration and Recoverable Local Data

Status: Accepted
Date: 2026-11-02
Feature IDs: DATA-001, DATA-002, DATA-003, AUTH-001, MONEY-001
Decision owner: Project maintainer; requested implementation of the version-management and engineering safeguards.

## Context

AI will implement much of the future work. The published repository initially has one English root commit, local tests, no CI/protected integration branch, and no release tags. Regression prevention needs executable checks and recoverable data boundaries as well as documentation.

## Options

1. Direct commits and informal checkpoints: simple, but allows unchecked regressions and unclear recovery points.
2. Short-lived branches, checked PRs, immutable baseline tags, and explicit data compatibility: adds review/build time while preserving one integration line.
3. Permanent development/release branches and a custom release service: more coordination than the current single-maintainer iOS project needs.

## Decision

Choose option 2. Require repository and native simulator checks, strict `main` protection, English squash commits, no routine force pushes, and protected release tags. Zero mandatory outside approvals avoids blocking a solo maintainer; task scope still controls merge/release authorization. Human review remains focused on product, financial/permission/data decisions, and actual family distribution.

Preserve the current app/schema/archive versions. A source tag never implies a database downgrade is safe. Prefer forward repair for upgraded data; any snapshot restore must state its lost transaction interval and preserve the replaced copy.

## Consequences

CI takes longer, including on documentation PRs. Hosting settings must be verified outside Git. Public CI is read-only, uses synthetic isolated storage, and carries no signing/cloud secrets. No new application dependency, server, sync mechanism, or release platform is introduced. The current local-feature baseline remains incomplete for cross-device release.

## Validation and recovery

Run the [common and native checks](../26-code-and-test-standards.md), verify required GitHub settings, and retain a sanitized baseline manifest. Keep failures as behavioral regressions. Follow the [recovery policy](../25-data-compatibility-and-recovery.md); use new revert/fix commits rather than rewriting public history.
