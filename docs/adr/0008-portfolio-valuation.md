# 0008. Portfolio valuation
Date: 2026-11-08
Status: Accepted (interpretation to be confirmed — see PROGRESS.md)
Deciders: Tech Lead, Staff Flutter Engineer

## Context
Market value = quantity × price; stream gives bid/ask/last. `last` can overstate what a market sell would yield (SELL fills at bid).

## Decision
Combine both: headline "approximate market value" uses `last`; a secondary "sell-now value" uses `bid`. An **info** control explains both and that values are estimates (and stale/halted states). Positions outside the watchlist are included in the stream subscription (union of symbols). Halted positions use `prevClose`, flagged. Cash always from server (`getAccount`), refreshed after fills.

## Options considered
`last` only; `bid` only; mid; **last + bid together (chosen)**.

## Consequences
+ User sees optimistic and conservative numbers. − Two numbers need clear labeling.

## Edge cases & mitigations
No price yet → show "—", never 0. Stale → dimmed + labeled. Fractional crypto quantities → Decimal math only. Subscription union changes on position change → stream swap policy (ADR stream).

## Amendment (2026-11-08)
The header is now the wallet balance of the home page (ADR-0019): total at `last` as the headline, with cash, assets-at-last and sell-now as three figures. The per-position breakdown moved to the holdings list, each row valued the same way (live quote, else `prevClose` flagged approximate, else "—").
