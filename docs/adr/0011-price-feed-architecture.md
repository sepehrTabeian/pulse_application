# 0011. Price feed architecture
Date: 2026-11-08
Status: Accepted (Tech Lead approved all QUESTIONS.md defaults, 2026-11-08)
Deciders: Tech Lead, Staff Flutter Engineer

## Context
The stream is single-subscription, at-least-once, unordered, up to 50 ticks/s, does not reconnect, does not follow watchlist changes, and sends malformed messages (README + simulator).

## Decision
- ONE owner: `PriceFeedService` (pure Dart, domain). UI reads it through `PriceFeedCubit`; rows use `BlocSelector` for their own symbol (one tick rebuilds one row).
- `PriceBook`: per-symbol `seq` dedupe (drops duplicates/older ticks); a snapshot replaces entries (resets baseline after reconnect).
- Coalescing: updates published at most every 150 ms.
- Reconnect: exponential backoff + jitter (`RetryPolicy.delayFor`), reset on first message.
- Symbol change: open a second connection, switch on its first message, then cancel the old one (no gap, no flicker); a failing candidate keeps the old stream and is retried.
- Subscription = union(watchlist symbols, position symbols) (ADR-0008).
- Staleness from silence (heartbeat every 2 s counts): stale > 6 s, offline > 15 s; computed with an injectable clock (`package:clock`, fakeable).
- Lifecycle: `pause()` on background (closes connection, cancels timers), `resume()` on foreground.
- Data layer drops malformed/unknown messages (never errors the stream).

## Consequences
+ Deterministic, testable with `fakeAsync`; no leaks (`openConnectionCount` 1→0 verified). − Thresholds are constants to be confirmed (Q2).

## Edge cases covered by tests
Duplicate/out-of-order ticks, error vs. plain close, repeated failures (no reconnect storm), symbol change twice quickly, failing candidate, pause during pending reconnect, dispose leaves no timers, messages from cancelled connections ignored, halted symbols (no ticks) not marked stale thanks to heartbeats.
