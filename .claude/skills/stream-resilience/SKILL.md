---
name: stream-resilience
description: Lifecycle and correctness rules for the Pulse price stream (reconnect, dedupe by seq, throttling, staleness, watchlist changes, leaks). Use when touching streamPrices, the price repository, or watchlist row updates.
---

# Stream resilience

- One connection owner (a single service), not per-widget subscriptions. Single-subscription stream ⇒ fan out via our own broadcast/state.
- Parse defensively: ignore unknown `type`, tolerate bad JSON; `error` messages (e.g. UNKNOWN_SYMBOL) are per-symbol, not fatal.
- **Dedupe/order:** keep `lastSeq[symbol]`; drop `seq <= lastSeq` (at-least-once + out-of-order). Snapshot replaces baseline.
- **Throttle:** up to 50 ticks/s ⇒ coalesce latest-per-symbol and publish at most once per ~100–250 ms / frame. Rebuild only the affected row.
- **Reconnect:** on `ConnectionLostException` or stream done ⇒ exponential backoff + jitter, cap; reset on success. Expect a fresh snapshot.
- **Staleness:** track last-message time (ticks + heartbeats). If silent > threshold or disconnected ⇒ mark prices stale (dimmed + "Stale · Xs ago" / banner). Never present stale price as live.
- **Watchlist change:** stream doesn't follow ⇒ debounce, open new stream, swap after first snapshot, then cancel old. Always cancel old (`openConnectionCount` should stay ≤ 2 transiently, 1 steady).
- **Lifecycle:** pause/close on app background, resume + reconnect on foreground; `dispose()` on teardown.
- **Halted instruments:** no ticks ever ⇒ not "stale"; show `prevClose` + HALTED badge.
- Price direction: color + icon/arrow + sign (a11y); flash briefly on change.
