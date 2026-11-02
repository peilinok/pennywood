# Architecture Decision Records

Create an ADR for a lasting decision about accounting contracts, module boundaries, parent/device authority, synchronization, schema/archive compatibility, dependencies/toolchain, or supported platforms. Small implementation details and ordinary bug fixes do not need one.

Use `NNNN-short-english-title.md`, starting after the highest existing number. Keep an accepted record immutable in meaning. A later record supersedes it and links both directions; do not rewrite history to hide a changed decision. Proposed records do not authorize product changes.

```markdown
# NNNN: Decision title

Status: Proposed / Accepted / Superseded by NNNN
Date: YYYY-MM-DD
Feature IDs:
Decision owner and approval reference:

## Context
Concrete problem, evidence, and constraints.

## Options
Two or three viable choices and their practical tradeoffs.

## Decision
Chosen contract and boundaries. State what requires explicit authorization.

## Consequences
Complexity, compatibility, privacy, operating cost, and limitations.

## Validation and recovery
Acceptance checks, migration implications, and recovery limits.
```

Current records: [0001: Protected integration and recoverable local data](0001-protected-integration.md).
