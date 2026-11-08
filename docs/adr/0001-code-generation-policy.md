# 0001. Code generation policy
Date: 2026-11-08
Status: Accepted
Deciders: Tech Lead, Staff Flutter Engineer

## Context
The lead forbids code generators for building models and logic. Question raised: does that include Flutter's official localization generator (`flutter gen-l10n`)?

## Decision
- Forbidden: any generator for models, serialization, DI, state, routing, business logic (`build_runner`, `freezed`, `json_serializable`, `injectable`, …).
- Allowed single exception: `flutter gen-l10n` for localization only.

## Options considered
1. Ban everything incl. gen-l10n; hand-write a `LocalizationsDelegate` — max purity, but more code, no ICU plural/gender tooling, error-prone for RTL/plurals.
2. Ban for logic/models, allow gen-l10n — official, no `build_runner`, ARB workflow suits translators. **Chosen.**

## Consequences
+ Models are hand-written and fully explainable (needed for defensive parsing and review).
+ Localization gets plural/ICU support and a translator-friendly format.
− More boilerplate for models (`copyWith`, `==`); accepted.
− Generated l10n output is committed and must be excluded from the standards script.

## Edge cases & mitigations
- A contributor adds `build_runner` "just for l10n" → script `ENF-02` rejects generator packages.
- Generated l10n edited by hand → forbidden; regenerate from ARB.
