# docs/

| File | Read it when |
|---|---|
| [CODING_STANDARDS.md](CODING_STANDARDS.md) | Before writing code. Mandatory rules with IDs (`ORD-*`, `ARCH-*`, `TECH-*`...), enforced by `tool/check_standards.sh` |
| [adr/](adr/README.md) | Before changing a design. One file per decision (0001-0022); amend or supersede, do not rewrite history |
| [QUESTIONS.md](QUESTIONS.md) | To see what was asked of the Tech Lead and which defaults are assumed (Q15-Q18 await confirmation) |
| [PROGRESS.md](PROGRESS.md) | To see what is done, verified, not verified and what remains |

## Working agreement
1. Decide with the Tech Lead, not for them: options, trade-offs, edge cases, a recommendation.
2. Record every non-trivial decision as an ADR and update `adr/README.md`.
3. Finish a task with tests, the four checks (root README), and an update to `PROGRESS.md`.
4. Commits are Conventional Commits, one logical change each.
5. `pulse_api` is never modified.
