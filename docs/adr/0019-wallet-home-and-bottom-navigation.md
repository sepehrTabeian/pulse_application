# 0019. Wallet home and bottom navigation
Date: 2026-11-08
Status: Accepted (Tech Lead requested a Trust-Wallet-like first page)
Deciders: Tech Lead, Staff Flutter Engineer

## Context
The first screen was only the watchlist with a floating "add" button that covered the last row. Users also confused symbols they *follow* with assets they *own*.

## Decision
- **Bottom navigation** (`NavigationBar`) with three destinations: wallet (home), orders, and "search & add". Search opens as its own screen, so the selected tab never moves to it. The floating button is removed.
- **Home = wallet.** Centered total balance, three figures under it (cash, assets at `last`, sell-now at `bid` — ADR-0008), then two switches: **holdings | watchlist** and **all | stocks | crypto**.
- **Holdings and watchlist are different lists** and look different: holdings rows show live price + change, the value in USD and the amount with its unit; they come from the server account, include positions that are not on the watchlist, open the ticket on tap and are never swipe-deletable. Watchlist rows show price and change only, carry a drag handle, and are deleted by swiping. Each tab has a hint banner (primary tint for holdings, neutral for watchlist) that says what the list is.
- The app opens on **holdings** (`HomeTab.holdings`); `WatchlistPage` defaults to the watchlist so existing flows and tests are unchanged.
- **Reorder and delete without an "Edit" mode:** `ReorderableListView` with explicit drag handles and `Dismissible` rows. The cubit removes a row at once and rolls back on a failed save (ADR-0013); `confirmDismiss` returns `false` so a fast rollback never leaves a dead, dismissed row. Reordering is offered only on the unfiltered list.
- **Stocks vs crypto:** `AssetClass` (`assetClassOf`) — from the instrument type, or a `-` in the symbol when the instrument is unknown. Crypto gets its own accent (`PulseSemanticColors.crypto`) on a round asset avatar (`PulseAssetAvatar`).
- Font: Vazirmatn bundled in the app (4 weights), set as the theme font family.

## Consequences
+ Owned vs followed is obvious; no covered rows; fewer taps to reorder/delete. − The header is tall on small phones (it scrolls with the list); a 3-way segmented filter must stay narrow for 360 dp panes (checked by the tablet tests).
