# `lib/`: app shell

| File | Role |
|---|---|
| `main.dart` | Builds the get_it container (`configureCoreDependencies`, `configureTradingDependencies`, `configureAppDependencies`) and runs `AppRoot` |
| `app.dart` | `PulseApp`: `MaterialApp` with the Pulse light/dark theme and the Persian locale |
| `app_root.dart` | **Composition root of the UI.** Creates the app-wide cubits from the container, wires them together, hosts the bottom navigation (`_HomeShell`: wallet / orders / search & add) and opens the ticket and search screens |
| `core/` | Cross-cutting code, see [core/README.md](core/README.md) |
| `features/` | One folder per feature, see [features/README.md](features/README.md) |

## What `AppRoot` does

- Creates `PriceFeedCubit`, `WatchlistCubit`, `PortfolioCubit`, `OrdersCubit`, `OrderRecoveryCubit` once and provides them
  with `MultiBlocProvider`.
- Feeds **one** price connection with the union of watchlist symbols and position symbols (listeners on the two cubits).
- Pauses the price feed when the app goes to the background and resumes it on return.
- On `AppLifecycleState.detached` it resets the container, which disposes the fake server (all sockets and timers).
- Starts on the **holdings** tab (`HomeTab.holdings`); `WatchlistPage` itself defaults to the watchlist.

Per-screen blocs (`OrderFlowBloc`, `CandlesCubit`, `SearchBloc`) are created when a screen opens and closed when it
closes; they are `registerFactory` in `core/di/app_injection.dart`.

## Adding a screen

1. Put it in the owning feature's `presentation/pages/`; create its bloc from `get_it` in `AppRoot` (never inside the page).
2. Route it with `Navigator.push` from `AppRoot` (there is no router package on purpose).
3. Add strings to `core/l10n/app_fa.arb` and run `flutter gen-l10n`.
