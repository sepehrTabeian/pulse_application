---
name: money-safety
description: Rules for order placement, idempotency, unknown outcomes (timeouts), and decimal arithmetic in Pulse. Use when touching the trade ticket, order repository, validation, or cost estimation.
---

# Money safety

## Numbers
- Never `double`. Parse API decimal strings into a decimal type (e.g. `package:decimal` / scaled integers). Serialize back to strings.
- Validate `quantity % lotSize == 0`, `limitPrice % tickSize == 0`, `quantity > 0` using exact arithmetic.
- Estimated cost: MARKET BUY → ask × qty, MARKET SELL → bid × qty, LIMIT → limitPrice × qty. Label it "estimated".

## Order state machine
`draft → submitting → filled | working | rejected(code,msg) | unknown`
- `clientOrderId` (UUID v4) is generated ONCE per submission attempt and **persisted before the network call**.
- Retries and reconciliation reuse the SAME id and SAME parameters (idempotency key). Edited params ⇒ new id (and the old attempt must be resolved first).
- Submit is single-flight: button disabled + guard in the controller (not only UI).
- `TimeoutException` ⇒ `unknown`, never "failed". Resolve by retrying `placeOrder` with the same id and/or `getOrder(id)`. `ORDER_NOT_FOUND` after timeout = not executed (confirm with lead).
- 503 (`isRetryable`) ⇒ bounded retry with backoff+jitter, same id. Other `ApiException` ⇒ show mapped, human-readable reason; no retry.
- `409 IDEMPOTENCY_CONFLICT` ⇒ bug indicator; surface and log.
- On app restart: reconcile any persisted non-terminal attempts.
- After FILLED: refresh account (cash/positions).

## UI
- Always show a terminal, unambiguous result: Filled (qty @ avg price) / Working (resting) / Rejected (reason) / Unknown→resolving.
- Halted (`tradable:false`): disable ticket with explanation; still handle `TRADING_HALTED` from server.
