---
name: adr-writing
description: Template and process for Architecture Decision Records in Pulse. Use after the Tech Lead approves a decision, and for the final ADR set.
---

# ADR process

Location: `docs/adr/NNNN-kebab-title.md`; index in `docs/adr/README.md`.

```
# NNNN. <Title>
Date: YYYY-MM-DD
Status: Proposed | Accepted | Superseded by NNNN
Deciders: <Tech Lead>, Staff Flutter Engineer

## Context
<forces, constraints from README, time box, risks>

## Decision
<what we chose>

## Options considered
<each with pros/cons>

## Consequences
<positive, negative, follow-ups>

## Edge cases & mitigations
<list>
```

Rules: one decision per ADR (group small ones in one "Conventions" ADR); never write Accepted without the lead's explicit approval; a changed decision gets a new ADR that supersedes the old.
