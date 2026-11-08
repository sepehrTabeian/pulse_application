# 0020. Order history and the local rejected-order log
Date: 2026-11-08
Status: Accepted (assumed default — see QUESTIONS.md Q15)
Deciders: Tech Lead, Staff Flutter Engineer

## Context
An orders tab must show filled, under-review, queued, rejected and cancelled orders. `pulse_api` is a backend we do not own (README rule: **do not modify it**). Its `getOrders()` returns only what it accepted: `FILLED`, `WORKING` (queued) and a transient `PENDING`. A refusal (422: funds, position, halted) is thrown as an error and is **not listed**. There is **no cancel endpoint**.

## Decision
- `OrderHistoryReader` (role interface) reads `getOrders()`; unknown statuses map to `OrderStatus.unknown`, an unreadable row is skipped, never hiding the rest. `OrderStatus` is extended with `pending`, `rejected`, `cancelled` so a future server can send them.
- **Rejected orders** are recorded by the app itself (`RejectedOrderLog`, `RejectedOrderLogImpl`): `OrderFlowBloc` writes one entry when the server definitively refuses an order (`OrderRejectedOutcome`), newest first, capped at 50, persisted as hand-written JSON through `KeyValueStore` with serialised writes (same pattern as ADR-0003). A failing log never blocks showing the rejection; a damaged entry is skipped.
- `OrdersCubit` merges server orders with the local rejections (de-duplicated by `clientOrderId`, newest first). The catalogue and the local log are best-effort: if either fails, the server's orders still show. A failed refresh keeps the old list and reports the error once.
- UI: two dropdowns — status (with counts) and asset class — plus clear empty / error / loading states; rejected cards show the reason through the normal error resolver.
- **Cancel is not offered.** The fake API cannot cancel; a local-only "cancel" would lie about the server state. The `cancelled` and `pending` filters stay in the list and are empty until the server sends them.

## Consequences
+ History works with the unmodified backend; refusals are not lost. − Rejections live only on this device (lost on reinstall) and local validation failures (never sent) are not recorded.
