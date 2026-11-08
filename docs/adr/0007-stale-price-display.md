# 0007. Stale price display
Date: 2026-11-08
Status: Accepted
Deciders: Tech Lead, Staff Flutter Engineer

## Context
The stream can drop or go silent; heartbeat arrives every 2 s. Users must never mistake an old price for a live one.

## Decision
- Stale = disconnected, or no message (tick/heartbeat/snapshot) for > 6 s (named constant, injected clock).
- Show BOTH: a global banner with an **info** action explaining the real state (what stale means, last update time, that reconnection is automatic, that orders are filled at server prices), and per-row dimming with "last update" age.
- Ticket: estimated cost is labelled "estimated" and, when stale, additionally "stale price" and dimmed. Warn only; block submit only when the connection is fully lost.
- Halted instruments are never "stale": shown with `prevClose` and a HALTED badge.

## Options considered
Banner only / rows only / both (**chosen**); warn vs block while stale (**warn, block only on full disconnect**).

## Consequences
+ Honest status in two places. − Slightly more UI. − Storm (disconnect ~10 s) means frequent banners; copy must be calm.

## Edge cases & mitigations
- Symbol without ticks but heartbeat alive → not stale. Reconnect before first snapshot → rows stay dimmed until snapshot. Clock changes → use monotonic clock. Banner flapping → hysteresis (min display time).
