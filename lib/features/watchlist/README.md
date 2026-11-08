# watchlist (and the home page)

Owns the **home page** (`WatchlistPage`) and the list of symbols the user follows. See ADR-0019 and ADR-0013.

## Pieces
- `domain/use_cases/load_watchlist.dart`: loads symbols and the catalogue in parallel (`LoadedWatchlist`).
- `domain/services/watchlist_rules.dart`: add / remove / move with the limit (20) and duplicate rules.
- `data/`: `WatchlistRepositoryImpl` (`WatchlistReader` / `WatchlistWriter`).
- `presentation/cubit/watchlist_cubit.dart`: **optimistic** edits, saves serialised and coalesced, rollback to the last
  server-confirmed list on failure, `retryFailedSave`.
- `presentation/pages/watchlist_page.dart`: balance header, **holdings | watchlist** tabs, **all | stocks | crypto**
  switch, hint banners, delete by swipe, reorder by drag handle, tablet two-pane (list + ticket).
- `presentation/widgets/watchlist_row.dart`: one followed symbol (price + change), listens to one symbol only.

## Behaviour worth knowing
- `HomeTab.holdings` (what you own, from the server account, rows are `HoldingRow` from `portfolio`) vs
  `HomeTab.watchlist` (what you follow). They look different on purpose.
- Reorder is only offered on the unfiltered list. Swipe uses `confirmDismiss` returning `false`; the cubit removes the
  row, so a fast rollback never leaves a dead dismissed row.
- The page does not build blocs: it receives callbacks (`onOpenTicket`, `onOpenSearch`, `ticketPaneBuilder`) from `AppRoot`.
- On a tablet the selected symbol opens in the right pane; while an order is in flight the list refuses to switch symbol.

## Tests
`test/features/watchlist/` (cubit, page, responsive, retry, rules).
