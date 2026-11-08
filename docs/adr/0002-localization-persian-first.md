# 0002. Localization: Persian first, English later
Date: 2026-11-08
Status: Accepted
Deciders: Tech Lead, Staff Flutter Engineer

## Context
Current release targets Persian users; English comes later. Trading UI mixes RTL text with LTR numbers and symbols (`AAPL`, `BTC-USD`).

## Decision
- `fa` is the default and only shipped locale now; `en` added later by adding an ARB file only.
- Use `flutter gen-l10n` with `app_fa.arb` as template (ADR-0001). No user-facing literals anywhere.
- Layouts are direction-agnostic from day one (directional EdgeInsets/Alignment).

## Options considered
1. English-only now, retrofit later — cheap now, expensive migration, RTL bugs later.
2. Persian-first with multi-locale structure — **chosen**; small upfront cost.

## Consequences
+ Adding English is data-only (ARB), no code change.
− Must test RTL rendering and bidi edge cases from the start.

## Edge cases & mitigations
- Symbols/prices are LTR islands inside RTL text → wrap in directional isolates / `TextDirection.ltr` for numeric/ticker widgets.
- Digit style (Persian vs Latin digits for prices) → open question, recorded in PROGRESS.md; formatting centralized in one formatter so it is a one-place change.
- Decimal separator and grouping differ per locale → formatters take locale; never go through `double`.
- Server error `message` is not localized → never shown verbatim; map `code` → ARB string.
- Missing translation key → analyzer/gen-l10n fails build (`required-resource-attributes`), plus a test that all keys exist for every locale.
