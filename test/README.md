# test/

Run everything with `flutter test`. Layout mirrors `lib/`:

| Path | What |
|---|---|
| `core/` | errors, retry policy, JSON reader, number formatting, DI, storage, logging |
| `features/<feature>/` | unit, bloc/cubit, widget and contract tests of each feature |
| `app_root_integration_test.dart` | End to end with the real container and real simulator (phone and tablet sizes) |
| `app_resilience_test.dart` | Demo-critical: chaos switch, `openConnectionCount == 1` lifecycle, teardown disposes the api |
| `app_test.dart` | App shell smoke test |
| `support/` | Shared fakes and harnesses |

## Support helpers
- `fakes.dart`: `testInstrument`, `testRequest`, `testOrder`, `ScriptedPlacer` (scripted order outcomes), `InMemoryPendingOrderStore`.
- `fake_trading_remote_source.dart`: scriptable `TradingRemoteSource`; unscripted calls fail loudly.
- `page_harness.dart`: `FakeBackend` (watchlist, catalogue, account) and `FakeFeedSource` (push snapshots and ticks).
- `in_memory_kv_store.dart`, `candle_fakes.dart`, `recording_logger.dart`.

## Conventions
- AAA structure, behaviour-focused names ("returns ... when ...").
- Fake time for anything with timers: `fakeAsync` in unit tests, `tester.pump(duration)` in widget tests. Never `sleep`.
- Live ticks keep scheduling frames: do not use `pumpAndSettle` on a screen with a live feed; pump fixed durations.
- Widget tests that tap a lower element: set `tester.view.physicalSize` and `devicePixelRatio = 1` so it is on screen.
- Contract tests (`features/real_api_*`) use the real `FakeTradingApi` with `ChaosConfig.instant` or a custom config.
- Always dispose the api and close cubits before the test ends (the framework fails on pending timers).
