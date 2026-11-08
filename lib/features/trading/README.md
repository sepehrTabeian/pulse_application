# trading

The order ticket and everything that keeps an order **certain**. Read ADR-0005 and ADR-0012 first; money safety rules
(`ORD-*`) are in `docs/CODING_STANDARDS.md`.

## Pieces
- `domain/entities/`: `OrderRequest`, `Order` (`OrderStatus`: pending, working, filled, rejected, cancelled, unknown),
  `PendingOrder`.
- `domain/services/`: `OrderValidator` (quantity multiple of `lotSize`, price multiple of `tickSize`, limit rules),
  `OrderCostEstimator`, `MaxOrderQuantity` (how much can be bought or sold).
- `domain/use_cases/submit_order.dart`: **persist, send, resolve with the SAME `clientOrderId`**. `reconcile_pending_orders.dart`:
  after a restart, lookup only, never re-send.
- `data/`: `OrderRepositoryImpl` (place = exactly one attempt; read/lookup may retry; also reads the order history),
  `PendingOrderStoreImpl` (persisted JSON), request/response models.
- `presentation/bloc/order_flow_bloc.dart`: single-flight state machine (checking, idle, sending, resolving, unresolved,
  completed, rejected); on a definitive server refusal it records the order in the rejected log (see `orders`).
- `presentation/cubit/ticket_form_cubit.dart`: draft, validation, estimate. `order_recovery_cubit.dart`: restart recovery notices.
- `presentation/pages/ticket_page.dart` (+ `widgets/`): side, type, quantity with unit, availability line
  (USD available when buying, sellable amount when selling, "max" button), estimate, status card.

## Red lines
1. A timeout is **unknown**, never "failed". The UI keeps the order unresolved until the server answers.
2. Never send the same order twice with a different id; double taps send one request; the form is inert while in flight.
3. The user cannot leave the ticket while an order is in flight.
4. Money values are `Decimal`, parsed with `NumberInput` (no comma).
5. A market order fills at the server's touch price; the estimate is only an estimate.

## Tests
`test/features/trading/` (validator, estimator, submit/reconcile with `fake_async`, bloc, ticket widget tests, contract
tests against the real simulator with ghost timeouts).
