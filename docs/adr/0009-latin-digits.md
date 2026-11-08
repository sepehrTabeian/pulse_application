# 0009. English (Latin) digits in the Persian UI
Date: 2026-11-08
Status: Accepted
Deciders: Tech Lead, Staff Flutter Engineer

## Context
UI is Persian/RTL but numbers (prices, quantities) must be unambiguous in a trading context.

## Decision
Always display Latin digits (0-9) with `.` decimal separator for prices/quantities/percentages. A single number formatter in presentation owns this. Input accepts Persian/Arabic-Indic digits and `٫`/`,` and normalizes to Latin before validation.

## Consequences
+ Matches symbols/API data, no conversion errors. − Mixed-script lines need LTR isolation.

## Edge cases & mitigations
Bidi: wrap numbers/tickers in LTR direction. Pasted text with mixed digit scripts or zero-width chars → normalize/strip. Never route Decimal through `double`.
