# Open questions for the Tech Lead

**STATUS: ALL 14 QUESTIONS ANSWERED — the Tech Lead approved every default on 2026-11-08.** Decisions are recorded in ADR-0010..0016 (Q1 → 0014, Q2 → 0007/0011, Q3/Q10/Q11/Q12/Q13 → 0015, Q4–Q7 → 0012, Q8 → 0008, Q9 → 0013/0015, Q14 → 0010). The table is kept as the audit trail of what was asked and assumed.

| # | Question | Default implemented | Risk if wrong | Change cost |
|---|---|---|---|---|
| Q1 | Parsing policy: skip-and-log invalid list items instead of failing the whole list; `tradable` missing ⇒ not tradable | Yes | A real instrument could be hidden if the server omits a field | Low (one mapper) |
| Q2 | Stale threshold / "fully lost" threshold | 6 s / 15 s without ANY message (heartbeat counts) | Banner flaps (too tight) or hides outage (too loose) | Constants in one class |
| Q3 | Watchlist rows show `last` + change (abs and %) vs `prevClose`; bid/ask only on the ticket | Yes | Traders may expect bid/ask in the list | Low |
| Q4 | After app restart, a pending order whose lookup returns `ORDER_NOT_FOUND` is treated as **not executed** (server answered; no re-send at restart) | Yes | In a real system a very recent order could still be in flight | Medium; policy in one use case |
| Q5 | Orders are never auto-re-sent after app restart (only looked up); only the user may re-submit | Yes | None for money; slight UX friction | Low |
| Q6 | Auto-resolve attempts after an unknown outcome: up to 6 re-sends of the SAME request/id with backoff (≈ 0.25 s → 4 s), then stay `unresolved` with a manual "check status" button | 6 attempts | Longer wait under `storm` | Constant |
| Q7 | Ticket while stale: warn + label estimated cost as stale; block submit only when the feed is **offline** (≥ 15 s) | Yes | MARKET fills at server price so risk is the displayed estimate only | Low |
| Q8 | Portfolio header: headline = approximate value by `last`; secondary "sell-now value" by `bid`; positions without live price use `prevClose` and are flagged approximate; info sheet explains | Yes | Two numbers may confuse | Low |
| Q9 | Watchlist edit failure policy: on failed save revert to the last **server-confirmed** list (not just undo the last change) and show a retry action | Yes | Loses several quick edits if one save fails | Medium |
| Q10 | Search: debounce 300 ms, min 1 character, max 10 results (server cap) | Yes | — | Constant |
| Q11 | Digits: Latin in UI (ADR-0009). Input accepts Persian/Arabic digits and `٫` as decimal separator; a comma `,` is **rejected** (ambiguous: "1,5" could be 15 or 1.5 — unsafe for money) | Yes | Users who type commas must retype | Low |
| Q12 | Scope cut: "Could" items (candles chart, tablet two-pane layout) are NOT implemented; accessibility basics (non-colour direction, semantics, 48dp targets) ARE | Yes | Fewer demo extras | Separate task |
| Q13 | Android emulator/device availability. Without it the app was verified by analyzer + unit/widget/contract tests only, never run on a device | Not run | UI polish/perf unverified on device | Needs an emulator |
| Q14 | ARCH-03 relaxed: presentation may depend on small **domain** role interfaces (e.g. `InstrumentSearcher`) for pass-through calls; use cases exist only where there is logic (submit/reconcile/load watchlist) | Yes (documented in ADR-0010) | Slight deviation from "always use cases" | Low |

## Added after approval (2026-11-08) — assumed defaults, need confirmation

| # | Question | Default implemented | Risk if wrong | Change cost |
|---|---|---|---|---|
| Q15 | The backend has no cancel and does not list rejected orders. Show rejected orders from a local log and offer **no** cancel (ADR-0020) | Yes | Rejections exist only on this device; users cannot cancel a queued order | Needs a server cancel endpoint |
| Q16 | The server sends no unit; derive `share`/coin ticker in the app and show max buy/sell on the ticket (ADR-0021) | Yes | A wrong unit if a new asset type appears | Low (one mapper) |
| Q17 | The demo chaos switch ships in the app bar of every build (ADR-0022) | Yes | A demo control visible to end users | Low (hide behind a flag) |
| Q18 | Values that "should come from the server" (candle ranges, stale thresholds 6 s/15 s, watchlist limit, status filters) stay app constants because `pulse_api` has no config endpoint | Yes | Changing them needs an app release | Needs a server config endpoint |

