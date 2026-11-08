# 0010. Use cases only where there is logic
Date: 2026-11-08
Status: Accepted (Tech Lead approved all QUESTIONS.md defaults, 2026-11-08)
Deciders: Tech Lead, Staff Flutter Engineer

## Context
Clean Architecture says presentation talks to use cases. Wrapping every one-line repository call in a class adds files without behaviour (YAGNI, 80-minute budget).

## Decision
- Use cases exist where there is real logic: `SubmitOrder`, `ReconcilePendingOrders`, `LoadWatchlist` (parallel join).
- Pass-through reads/writes depend directly on small **domain** role interfaces (ISP): `InstrumentSearcher`, `AccountReader`, `WatchlistWriter`.
- Presentation never imports data/models/`pulse_api` (enforced by `LAYER-*` rules in the standards script).

## Consequences
+ Fewer empty classes; every class earns its place. − Slight deviation from the strictest reading of the rule; a use case can be introduced later without touching callers' contracts.
