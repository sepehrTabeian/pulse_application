# `lib/features/`

One folder per feature. Each follows the same layout:

```
<feature>/
  domain/          pure Dart: entities, role interfaces (repositories), services, use cases
  data/            DTO models (tolerant parsing), repository implementations
  presentation/    cubit/bloc, pages, widgets
```

**Dependency rule:** `presentation → domain ← data`. Domain imports nothing from Flutter, `pulse_api`, data or
presentation. Only `data/` (and `core/di`) may import `package:pulse_api`. `tool/check_standards.sh` enforces this.

| Feature | Owns | README |
|---|---|---|
| `instruments` | Catalogue, search, `Instrument`, units, stocks vs crypto | [README](instruments/README.md) |
| `prices` | Live price stream, dedupe, reconnect, staleness | [README](prices/README.md) |
| `watchlist` | Home page, watchlist load/edit | [README](watchlist/README.md) |
| `portfolio` | Account, valuation, holdings rows, balance header | [README](portfolio/README.md) |
| `trading` | Order ticket, safe submission, recovery, availability | [README](trading/README.md) |
| `orders` | Order history, local rejected-order log | [README](orders/README.md) |
| `candles` | Candle data and chart section | [README](candles/README.md) |
| `demo` | Chaos switch | [README](demo/README.md) |

## Who depends on whom

```
instruments  <-  watchlist, orders, portfolio (holding rows), trading
prices       <-  watchlist, portfolio, trading (ticket form), candles (live last bar)
portfolio    <-  watchlist (home header, holdings), trading (availability)
trading      <-  orders (Order entity, rejected log is written by OrderFlowBloc)
```

Features share entities through `domain/` only; presentation code of one feature may use a widget or entity of another
(e.g. `HoldingRow` uses `PriceFeedCubit`), but never its data layer.

## Adding a feature

1. Create `domain/`, `data/`, `presentation/` with the smallest role interfaces you need.
2. Register the repository in `core/di/trading_injection.dart` and the cubit in `core/di/app_injection.dart`.
3. Provide the cubit in `app_root.dart` (app-wide) or create it when the screen opens (per-screen).
4. Tests first for anything with logic; fakes live in `test/support`.
5. Run the four checks in the root README.
