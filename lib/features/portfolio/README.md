# portfolio

The account as the server reports it (cash and positions) and its valuation. ADR-0008.

## Pieces
- `domain/entities/account.dart`: `Account`, `Position`.
- `domain/services/portfolio_valuation.dart`: `PortfolioValuation.compute(account, quotes, instruments)`. Per position:
  value at `last`, value at `bid` ("sell now"); no live quote falls back to `prevClose` (flagged approximate); no price
  at all is "no price" (shown as "—", never 0).
- `data/`: `AccountModel`, `AccountRepositoryImpl`.
- `presentation/cubit/portfolio_cubit.dart`: `load()`; keeps the previous account visible while refreshing or when a
  refresh fails. Reloaded after every filled order.
- `presentation/widgets/portfolio_header.dart`: wallet balance (total at `last`), cash / assets / sell-now figures,
  info sheet.
- `presentation/widgets/holding_row.dart`: one owned asset: name, live price and change, value and amount with unit.

## Rules
- Cash and positions are never computed locally (SSOT-01); after a fill, reload from the server.
- Decimal math only.
- Positions outside the watchlist are still subscribed to the price feed (`PriceFeedCubit.setPositionSymbols`).

## Tests
`test/features/portfolio/`, wallet cases in `test/features/watchlist/watchlist_page_test.dart`.
