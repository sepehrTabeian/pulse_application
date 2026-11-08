# 0004. Design system as one package, Material 3 tokens
Date: 2026-11-08
Status: Accepted
Deciders: Tech Lead, Staff Flutter Engineer

## Context
A design system must be an independent module. No designer tokens exist yet; they will arrive later.

## Decision
- One local package `packages/pulse_design_system` containing tokens, themes and widgets (not split into several packages). The rest of the app is a single app package.
- Initial tokens derive from Material 3 (`ColorScheme.fromSeed`, M3 typography/shape). Semantic tokens (`priceUp`, `priceDown`, `stale`, `halted`, spacing, radii) are exposed via our token classes/`ThemeExtension`.
- Depends on nothing from the app; all strings passed in.

## Options considered
1. Theme inside the app — no isolation, rejected by the lead.
2. Several packages (tokens/widgets/theme) — more overhead than the time box allows.
3. One package — **chosen**.

## Consequences
+ Designer tokens replace values in one place; features untouched.
− Semantic tokens must be chosen carefully now to avoid breaking renames later.

## Edge cases & mitigations
- Up/down/stale must not rely on color (DS-05) — color-blind and high-contrast checked in widget tests.
- Dark mode contrast for price colors → verify contrast ratio in tests.
- Large text scale / RTL → widget tests at textScale 2.0 and RTL.
