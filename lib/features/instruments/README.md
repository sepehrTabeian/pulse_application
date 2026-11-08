# instruments

The catalogue of tradable instruments, symbol search and the helpers that tell stocks from crypto.

## Pieces
- `domain/entities/instrument.dart`: `Instrument` (symbol, name, `InstrumentType`, `tickSize`, `lotSize`, `prevClose`,
  `tradable`, `unit`). `tickSize`/`lotSize` are always > 0, otherwise the row is skipped.
- `domain/entities/asset_class.dart`: `AssetClass { stock, crypto }` and `assetClassOf(symbol, instrument?)` (a `-` in the
  symbol means crypto when the instrument is unknown).
- `domain/repositories/`: `InstrumentCatalog`, `InstrumentSearcher` (role interfaces).
- `data/`: `InstrumentModel` (tolerant parsing) and `InstrumentRepositoryImpl`.
- `presentation/bloc/search_bloc.dart` + `pages/search_page.dart`: search with 300 ms debounce, restartable.
- `presentation/unit_label.dart`: unit text (`share` shows "سهم").
- `presentation/asset_style.dart`: accent colour per asset class (token from the design system).

## Behaviour worth knowing
- The server sends no `unit`; the model derives it: `share` for stocks/ETFs, the ticker for crypto (`BTC-USD` is `BTC`).
- Server type `EQUITY` is a stock. Unknown types become `InstrumentType.other` and are treated as stocks in the UI.
- A missing `tradable` means **not tradable** (safe side). Invalid rows are skipped and logged (ADR-0014).
- Search: at least 1 character, at most 10 results (server cap); an old response never overwrites a newer query.

## Tests
`test/features/instruments/`, `test/features/watchlist/` (asset split on the home page).
