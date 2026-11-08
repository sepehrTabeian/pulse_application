# 0015. Product scope and UX decisions
Date: 2026-11-08
Status: Accepted (Tech Lead, Q3, Q10, Q11, Q12, Q13)
Deciders: Tech Lead, Staff Flutter Engineer

## Decisions
- **Q3 Rows:** watchlist rows show only `last` and the change (absolute and %) vs `prevClose`. `bid`/`ask` appear only on the ticket.
- **Q10 Search:** 300 ms debounce (RxDart + Bloc), minimum 1 character, at most 10 results (server cap), restartable so an old response never overwrites a new query.
- **Q11 Numbers:** Latin digits in the UI. Input accepts Persian/Arabic digits and the decimal separators `.` and `٫`; a comma `,` is **rejected** (the keyboard filter does not even let it in) because "1,5" is ambiguous for money.
- **Q12 Scope:** Must and Should are implemented. Candles chart and tablet layout were first out of scope and were added later (ADR-0017, ADR-0018); the wallet home, orders tab and demo switch followed (ADR-0019..0022). Accessibility is in scope: direction is never colour-only (icon + sign + semantic label), 48 dp touch targets, semantics on rows and status banners.
- **Q13 Verification limit:** the app was first verified by analyzer, unit, bloc, widget, contract and an end-to-end widget test (94.7% line coverage) only. Since 2026-11-08 it has also been run on an Android phone emulator (API 36) and checked by screenshot for the home, ticket, search and orders screens; the integration tests and real-device performance at 50 ticks/s are still unverified.
- **Q9 Retry:** a failed watchlist save rolls back to the last server-confirmed list and the snackbar offers "retry", which re-applies and saves the failed edit (invalidated by any newer edit or reload).

## Consequences
Smaller, readable list rows; no money ambiguity; honest statement of what is not yet verified.
