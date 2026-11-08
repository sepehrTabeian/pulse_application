# tool/: standards checker

`tool/check_standards.sh` runs `tool/check_standards.dart`, a heuristic linter for the rules in
`docs/CODING_STANDARDS.md` (ADR-0006). It exits non-zero on any violation and prints `file:line RULE message`.

```bash
tool/check_standards.sh            # check the project
flutter test tool/test             # tests of the checker itself
```

Examples of what it catches: Flutter imports in a `domain/` file, `package:pulse_api` outside `data/` and DI,
`double` for money, `as` casts on external JSON, raw colours in feature code, generated-code packages, `print`,
oversized files.

- Rules live in `tool/standards/checker.dart`; each has an ID (`LAYER-02`, `CAST-01`, `COLOR-01`, ...).
- The checker is heuristic (it reads text, not the analyzer). When you add a rule, add a test in
  `tool/test/check_standards_test.dart` with a passing and a failing sample.
- Never silence a violation by editing the checker; fix the code or write an ADR.
