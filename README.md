# Pulse

A Flutter trading app on top of a **simulated** backend (`../pulse_api`). It has a wallet home (holdings and
watchlist, stocks and crypto), live prices that survive a hostile network, a safe order ticket, an order history,
and candle charts. Persian (RTL) first.

> **`pulse_api` is a backend we do not own: never modify it** (`../pulse_api`, a sibling folder of this repo).
> It has no cancel endpoint, no config endpoint and does not list rejected orders; the app works around that (ADR-0020).

Stack: Flutter 3.10+ (Dart 3.10) · Bloc/Cubit · get_it · RxDart · Clean Architecture · `Decimal` for all money.
**No code generation** except `flutter gen-l10n` (ADR-0001).

## Quick start

```bash
git clone <this repo> pulse && git clone <pulse_api repo> pulse_api   # side by side: ../pulse_api must exist
cd pulse
flutter pub get
flutter gen-l10n          # only after editing lib/core/l10n/app_fa.arb
flutter run               # Android preferred
```

Demo under a bad network: tap the ⚡ switch in the home app bar (ADR-0022).

## Verify before every commit

```bash
flutter analyze
flutter test                          # unit, bloc, widget, contract, end-to-end widget tests
flutter test tool/test                # the standards checker itself
(cd packages/pulse_design_system && flutter test)
tool/check_standards.sh               # architecture / safety rules (docs/CODING_STANDARDS.md)
```

All four must be green. Commits follow Conventional Commits (`feat|fix|refactor|docs|test|chore|perf|ci(scope): subject`).

## Map of the repository

| Path | README | What |
|---|---|---|
| `lib/` | [lib/README.md](lib/README.md) | App entry, composition root, how the pieces connect |
| `lib/core/` | [lib/core/README.md](lib/core/README.md) | Errors, DI, JSON reading, formatting, storage, l10n |
| `lib/features/` | [lib/features/README.md](lib/features/README.md) | Feature layout, dependency rules, feature index |
| `lib/features/instruments` | [README](lib/features/instruments/README.md) | Catalogue, search, units, stocks vs crypto |
| `lib/features/prices` | [README](lib/features/prices/README.md) | Live price feed, staleness, reconnect |
| `lib/features/watchlist` | [README](lib/features/watchlist/README.md) | Home page, watchlist editing |
| `lib/features/portfolio` | [README](lib/features/portfolio/README.md) | Account, valuation, holdings |
| `lib/features/trading` | [README](lib/features/trading/README.md) | Ticket, safe order submission and recovery |
| `lib/features/orders` | [README](lib/features/orders/README.md) | Order history, rejected-order log |
| `lib/features/candles` | [README](lib/features/candles/README.md) | Candle chart data |
| `lib/features/demo` | [README](lib/features/demo/README.md) | Chaos switch (demo control) |
| `packages/pulse_design_system` | [README](packages/pulse_design_system/README.md) | Theme, tokens, shared widgets |
| `test/` | [test/README.md](test/README.md) | Test layout, fakes, how to write tests here |
| `integration_test/` | [README](integration_test/README.md) | Tests for a real emulator |
| `tool/` | [tool/README.md](tool/README.md) | The standards checker |
| `docs/` | [docs/README.md](docs/README.md) | Standards, ADRs, progress, open questions |

## The rules that matter most

1. **Money safety** (ADR-0005): never `double` for money, price or quantity; never send an order twice; the user must
   always learn the outcome of an order. A timeout is *unknown*, not *failed*.
2. **Clean Architecture** (ADR-0016): `presentation → domain ← data`. Only `data/` and the composition root import
   `package:pulse_api`.
3. **Server is the source of truth** (SSOT): cash, positions, orders and the watchlist come from the server and are
   re-read after changes; the app never invents them.
4. **Parse defensively** (ADR-0014): the backend returns raw JSON strings; a bad row is skipped, never fatal.
5. **Latin digits** in the Persian UI (ADR-0009); input accepts Persian/Arabic digits but rejects a comma.

## Data flow (price stream to one row)

`FakeTradingApi` → `FakeTradingApiRemoteSource` → `RemoteCallGuard` (error mapping) → `PriceStreamRepositoryImpl`
(drops malformed) → `PriceFeedService` (seq dedupe, coalescing, reconnect, staleness) → `PriceFeedCubit` →
`BlocSelector` in `WatchlistRow` / `HoldingRow` (only that symbol rebuilds).

## Where to continue

Open items, in rough priority order (details in [docs/PROGRESS.md](docs/PROGRESS.md) and [docs/QUESTIONS.md](docs/QUESTIONS.md)):

- Run `integration_test/` on an emulator (blocked so far by the Gradle/Maven network, see PROGRESS).
- A server config endpoint for values that are constants today (candle ranges, stale thresholds, watchlist limit; Q18).
- Order cancel, once the backend supports it (Q15); today the Orders tab has no cancel by design (ADR-0020).
- Hide the demo chaos switch behind a flag for production builds (Q17).
- English localization (add `app_en.arb`; ADR-0002), tablet polish of the new wallet home, price flash animation.
- Raise coverage back above 90 % (last measured 94.7 % before the latest features).

Read [docs/CODING_STANDARDS.md](docs/CODING_STANDARDS.md) and the ADR index before changing anything non-trivial.
Decisions that are not in an ADR are undecided: write one (skill: `.claude/skills/adr-writing`).
