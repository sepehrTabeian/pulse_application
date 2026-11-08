---
name: flutter-testing
description: Test strategy for Pulse risky logic (order state machine, stream dedupe/reconnect, decimal validation, optimistic watchlist rollback). Use when writing or reviewing tests.
---

# Testing

Priority (risk-first):
1. Order submission: double-tap ⇒ one `placeOrder`; timeout ⇒ `unknown` then resolved with same `clientOrderId`; 503 retry; rejection mapping.
2. Stream processor: out-of-order/duplicate `seq` dropped; snapshot reset; reconnect after `ConnectionLostException`; staleness after silence (use `fake_async`).
3. Validation: tickSize/lotSize with fractional crypto (`0.0001`), no float error.
4. Watchlist optimistic update + rollback on failure; serialized writes.

How:
- Depend on an interface (repository/gateway) so logic is testable without the real fake API; use `ChaosConfig.instant` or a hand-written fake that scripts failures deterministically.
- AAA structure, descriptive names. Pure-Dart unit tests for domain; widget tests only for key states (loading/error/empty/halted/stale).
- Never assert on timing with real `Future.delayed`; use `fake_async`.
- Coverage target: 80% on domain/application layers.
