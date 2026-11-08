# 0012. Order submission flow and recovery
Date: 2026-11-08
Status: Accepted (Tech Lead approved all QUESTIONS.md defaults, 2026-11-08)
Deciders: Tech Lead, Staff Flutter Engineer

## Context
Orders must never be sent twice by accident and the user must always learn the outcome, even with 15% ghost timeouts (order executed, client sees timeout) in `storm`.

## Decision
- `SubmitOrder` use case: persist attempt → send → on unknown outcome (timeout, 503, unreadable response, unknown status, other client error) re-send the SAME payload and `clientOrderId` with backoff (max 6, Q6) → confirmed / rejected / unresolved. Definite server rejections stop at once (incl. idempotency conflict).
- `OrderFlowBloc` is a single-flight state machine (`droppable` + state guard): Checking → Idle → Sending → Resolving → Completed | Rejected | Unresolved. All in-flight states are "locked": UI button pending, fields disabled, back navigation blocked.
- `Unresolved` is NOT a failure: stays locked; only the user's "check status" re-sends the same request.
- On start `ReconcilePendingOrders` only LOOKS UP unconfirmed attempts (never re-sends, Q5); `ORDER_NOT_FOUND` ⇒ not executed (Q4). A pending order for the same symbol locks its ticket (ORD-07).
- Account refreshed from the server after a confirmed fill (never computed locally).
- Client-side validation (`OrderValidator`, exact `Decimal`) blocks invalid input before any request; cost estimate is labelled as estimate with its basis (ask/bid/limit/last).

## Consequences
+ Verified end-to-end against the simulator's ghost timeout: executes exactly once. − Under storm the user may wait several seconds in "Resolving"; copy tells them not to resend.

## Edge cases covered by tests
Double/triple tap, submit after completion, edit during resolution, rejection then corrected retry (new id), storage failure (nothing sent), cleanup failure, closing the bloc mid-flight, corrupt persisted entries, concurrent store writes, exact decimals (0.3 vs 0.1), Persian digits, comma rejected, halted instrument, offline feed.
