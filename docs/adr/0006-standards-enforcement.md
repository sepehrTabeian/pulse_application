# 0006. Automated standards enforcement
Date: 2026-11-08
Status: Accepted
Deciders: Tech Lead, Staff Flutter Engineer

## Context
`docs/CODING_STANDARDS.md` is only effective if violations are caught mechanically, including AI-generated code.

## Decision
Two layers: strict `analysis_options.yaml`, plus `tool/check_standards.sh` — a thin wrapper over a Dart checker (`tool/standards/checker.dart`) that strips comments/strings before applying regex rules mapped to rule IDs. (Implemented in Dart rather than grep/awk: portable across macOS/Linux, correct comment/string handling, unit-testable with `flutter test`.) The script's own behavior is covered by tests with fixtures, including edge cases; a rule without a test is not accepted.

## Options considered
1. Analyzer only — cannot express architecture/import-boundary rules cheaply.
2. `custom_lint` — extra dependency, plugin API churn, generator-adjacent tooling.
3. Analyzer + tested script — **chosen**.

## Consequences
+ Fast feedback, CI-friendly, rule IDs in output.
− Grep rules are heuristic → false positives/negatives; mitigated by fixtures and an explicit allow-list mechanism requiring a written reason.

## Edge cases & mitigations
- Matches in comments/strings, `import … as`, identifiers like `doubleTap`/`printer`, generated l10n dir, CRLF, spaces/unicode in paths, empty/missing dirs, binary/huge files — all in the fixture suite (ENF-03).
