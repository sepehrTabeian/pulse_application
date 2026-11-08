# 0018. Responsive layout: phone single pane, tablet two panes
Date: 2026-11-08
Status: Accepted (Tech Lead requested the tablet layout, "Could #10")
Deciders: Tech Lead, Staff Flutter Engineer

## Context
Tablets should show the watchlist and the selected instrument (chart + ticket) side by side. Orders must stay safe when the layout changes.

## Decision
- `AdaptiveLayout.isTwoPane(size)`: width >= 600 dp AND height >= 480 dp. A phone in landscape (wide but short) stays single pane.
- Two-pane: fixed 380 dp list pane + detail pane; detail content is capped at 640 dp so fields never stretch.
- The same `TicketPage` is used for both forms (`embedded` flag). `TicketPaneHost` owns the pane's order-flow bloc and candles cubit and closes them on dispose.
- **Order safety:** while an order is in flight (Sending / Resolving / Unresolved) the list refuses to switch symbol (snackbar explains) so a live order flow can never be disposed. If the window becomes narrow mid-order, the pane stays on screen (global key keeps its state) instead of being rebuilt.
- Phone behaviour is unchanged (full-screen push, back blocked while locked).

## Consequences
+ One ticket implementation, tested at both sizes. − Switching symbol is deliberately blocked while an order is unresolved.
