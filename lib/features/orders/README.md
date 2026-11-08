# orders

The **Orders tab**: history of orders with status and stocks/crypto filters. ADR-0020.

## Pieces
- `domain/repositories/order_history.dart`: `OrderHistoryReader` (server orders, newest first) and `RejectedOrderLog`
  (orders the server refused; the server does not list them).
- `data/rejected_order_log_impl.dart`: last 50 rejections, persisted as JSON through `KeyValueStore`, serialised writes,
  damaged entries skipped. Written by `OrderFlowBloc` (trading) when the server refuses an order.
- `presentation/cubit/orders_cubit.dart`: merges server orders and local rejections (de-duplicated by `clientOrderId`),
  filters (`OrderFilter`, `AssetClass`), counts per status. A failed refresh keeps the old list.
- `presentation/pages/orders_page.dart`: two dropdowns, cards (side, type, quantity with unit, prices, status chip,
  rejection reason), empty / error / loading states, pull to refresh.

## Constraints of the backend
- Server statuses: `FILLED`, `WORKING` (queued), transient `PENDING`. `REJECTED` and `CANCELLED` are modelled but come only
  from the local log (rejected) or from a future server (cancelled).
- **There is no cancel**, so the page has no cancel button. Do not fake one locally.
- The Orders tab reloads each time it is selected.

## Tests
`test/features/orders/orders_test.dart`, `test/features/trading/presentation/order_flow_bloc_test.dart` (recording).
