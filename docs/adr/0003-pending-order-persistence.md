# 0003. Persist pending orders locally
Date: 2026-11-08
Status: Accepted
Deciders: Tech Lead, Staff Flutter Engineer

## Context
`placeOrder` can time out after the server executed the order (ghost timeout). The app may be killed before we learn the outcome. The `clientOrderId` is the only handle to resolve it.

## Decision
Persist each order attempt (`clientOrderId`, full request payload, status, timestamps) **before** sending, using `shared_preferences` with hand-written JSON (no generator). Wrapped behind a `PendingOrderStore` interface (DIP). Reconcile non-terminal attempts on app start.

## Options considered
1. Memory only — loses the id on kill; unknown outcome forever. Rejected.
2. `shared_preferences` + manual JSON — tiny, no codegen. **Chosen.**
3. `drift`/`sqflite` — overkill, drift needs codegen.
4. `flutter_secure_storage` — not needed; no secrets.

## Consequences
+ Idempotent recovery after crash/kill.
− Extra write on the critical path (small); storage failure must be handled.

## Edge cases & mitigations
- Storage write fails before send → do NOT send the order (cannot guarantee recovery); show error.
- Corrupt/old-schema JSON on read → tolerant parser, drop only the corrupt entry, log.
- Terminal state reached → remove/archive record; bounded history size.
- Same payload resubmitted by user after kill → reconcile first (ORD-07).
