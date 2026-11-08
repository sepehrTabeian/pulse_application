# prices

The single live price feed of the whole app (ADR-0011, ADR-0007). **One connection** for the watchlist symbols plus
the position symbols.

## Pieces
- `data/price_stream_repository_impl.dart` + `data/models/`: parse stream messages (`snapshot`, `tick`, `heartbeat`,
  `error`), drop malformed ones.
- `domain/services/price_feed_service.dart`: the core. Dedupes by per-symbol `seq`, coalesces bursts (publishes every
  150 ms), reconnects with backoff, swaps symbols without a gap, tracks staleness, supports pause/resume.
- `domain/entities/`: `PriceQuote`, `PriceBook`, `PriceFeedState` (`FeedStatus`: connecting, live, stale, offline;
  `isReconnecting`), `PriceChange` (vs `prevClose`).
- `presentation/cubit/price_feed_cubit.dart`: exposes the state; `setWatchlistSymbols`, `setPositionSymbols`,
  `pause`, `resume`.
- `presentation/widgets/feed_status_banner.dart`: banner (connecting / stale / offline) with an info sheet. A dropped
  socket is shown immediately, not only after the stale timer.

## Rules
- Stale after **6 s** without ANY message (a heartbeat counts), offline after **15 s**. Constants in `PriceFeedService`.
- Rows read ONE symbol with `BlocSelector`, so a tick of another symbol never rebuilds them.
- Never keep a second subscription: use the shared cubit. Tests assert `api.openConnectionCount == 1`
  (`test/app_resilience_test.dart`).
- The backend stream does not reconnect or follow watchlist changes: this service does both.

## Tests
`test/features/prices/` (service uses `fake_async`), `test/app_resilience_test.dart` (leaks, storm, teardown).
