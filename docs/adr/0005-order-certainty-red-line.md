# 0005. Order certainty red line
Date: 2026-11-08
Status: Accepted
Deciders: Tech Lead, Staff Flutter Engineer

## Context
Orders move money. Timeouts leave the outcome unknown. The lead's red line: never guess an order's outcome until the response is certain.

## Decision
- No optimistic updates for orders, cash or positions. A result (FILLED/WORKING/REJECTED) is shown only after server confirmation.
- Uncertain outcome ⇒ `unknown` state; resolve with the same `clientOrderId` and identical payload (idempotency), bounded retry with backoff + jitter.
- After submit: UI pending, submit disabled, inputs locked, dismissal guarded; single-flight enforced in the Bloc.
- Exhausted retries keep `unknown` with manual "check status" — never converted to failure.

## Options considered
1. Treat timeout as failure and let user retry — can double-execute under a new id. Rejected.
2. Optimistic "assume filled" — violates red line. Rejected.
3. Idempotent same-id resolution — **chosen**.

## Consequences
+ No lost/duplicated orders under ghost timeouts.
− User may wait in `unknown` for several seconds under storm; UX copy must explain it.

## Edge cases & mitigations
- Double tap / event while pending → ignored by Bloc.
- User edits fields mid-resolution → impossible (locked); new attempt only after resolution.
- `409 IDEMPOTENCY_CONFLICT` → bug path, surfaced, no auto new id.
- App killed mid-flight → persisted attempt reconciled on start (ADR-0003).
- Halted instrument → `TRADING_HALTED` is a definitive rejection.
