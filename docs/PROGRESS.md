# PROGRESS

All questions in [QUESTIONS.md](QUESTIONS.md) are answered and recorded in ADR-0010..0016.
Added after approval: a "retry" action on the snackbar when a watchlist save fails (Q9).

## Done and approved
- **Task 0** Agent scaffolding (AGENT.md, CLAUDE.md, skills)
- **Task 1** Coding standards + ADR-0001..0009
- **Task 2** Project foundation, core, design-system skeleton, tested standards checker
- **Task 3** Domain + data layer, defensive parsing, contract tests against the real simulator

## Tasks 4–6 (implemented and APPROVED by the Tech Lead on 2026-11-08; all QUESTIONS.md defaults accepted)

### Context
Build the vertical slice: live watchlist, resilient data, trade ticket, order safety, tests (Must 1–5),
plus Should 6–8 (edit/reorder, search, portfolio header).

### Decision (details in ADR-0010..0013)
- **Prices:** one `PriceFeedService` (seq dedupe, 150 ms coalescing, backoff reconnect, gap-free symbol swap, staleness 6 s / offline 15 s, pause/resume). Banner + dimmed rows + info sheet (ADR-0007).
- **Orders:** `SubmitOrder` (persist → send → resolve with the SAME id), `OrderFlowBloc` single-flight state machine, locked UI while in flight, manual "check status", restart reconciliation by lookup only.
- **Watchlist:** optimistic edits, serialised/coalesced saves, rollback to server-confirmed list.
- **Search:** RxDart debounce + restartable inside a Bloc.
- **Portfolio:** header with approximate value (last) and sell-now value (bid) + info (ADR-0008).
- **Design system:** `PulsePriceChange` (icon + sign + semantics, never colour only), `PulseStatusBanner`, `PulsePrimaryButton` (pending state), state views, info sheet.
- **Localization:** Persian/RTL; ~100 ARB messages; Latin digits (ADR-0009).

### Result — verified in this session
| Check | Result |
|---|---|
| `flutter analyze` (strict lints) | No issues |
| App tests (unit, bloc, widget, contract, e2e) | 434 passed |
| Standards-checker tests | 63 passed |
| Design-system tests | 25 passed |
| `tool/check_standards.sh` | 0 violations (it caught a real one: Flutter import in a domain service — fixed) |
| Line coverage `lib/` (no generated l10n) | 94.7% |
| Largest file | 443 lines (limit 800) |
| Generators in pubspec / generated model files | none |

Highlights proven by tests:
- **Ghost timeout** against the real simulator: order executes exactly once; UI never shows "failed" for a timeout.
- Double/triple tap sends one request; UI is inert and cannot be left while pending.
- 30% malformed + 20% duplicate/out-of-order messages do not break the feed; a forced disconnect reconnects; cancelling releases the connection.
- End-to-end widget test with real DI + real simulator: watchlist shows, exactly one stream connection, a market order is filled.

### Honest limitations
- **Never run on a device/emulator** (Q13). Verified by analyzer, unit, widget, contract and an end-to-end widget test only. Real-device layout, keyboard behaviour, and performance at 50 ticks/s are unmeasured.
- TDD: RED was observed for models, repositories, price feed, submit-order and order-domain tests. Written together with implementation (no RED observed): `JsonReader`, number formatting, DS widgets, bloc/cubits for watchlist/search/portfolio/order-flow/ticket-form, and the page widget tests.
- "Could" items NOT done: candles chart, tablet two-pane layout (Q12).
- Price-flash animation on tick not implemented (direction is shown by icon + sign + label).
- Only Persian strings exist (English later by adding an ARB file).
- Standards checker is heuristic (see ADR-0006); STR-01 only recognises common widget patterns.
- `getOrders` (history) and an order-history screen are not built.
- Git: the repository is now initialised and the work is committed (see the end of this file).

### Prepared commit messages
- `chore: scaffold flutter project with strict analysis and l10n`
- `feat(design-system): add material 3 theme, semantic tokens and core widgets`
- `feat(core): add exception model, mapper, retry policy, di and rxdart debounce`
- `feat(data): add defensive json reader, models and repositories for pulse_api`
- `feat(prices): add price feed service with dedupe, reconnect and staleness`
- `feat(trading): add safe order submission flow with persistence and recovery`
- `feat(watchlist): add live watchlist with optimistic editing, search and portfolio header`
- `docs: add standards, adrs, questions and progress`
- `test: add contract, widget and end-to-end tests`

### Remaining
- **Next step: run and visually verify on an Android emulator/device** (layout, RTL, keyboard, 50 ticks/s performance, `storm` demo) — never done so far (ADR-0015).
- Run on an Android emulator/device and fix what only a device shows.
- "Could": price chart (`getCandles`), tablet layout; optional tick flash animation.
- Split-work plan for a 3–4 engineer team (suggested): (1) feed/stream + staleness UX, (2) ticket/order flow + recovery, (3) watchlist/search/portfolio, (4) design system + l10n/English + a11y audit + CI running `analyze`, tests and `check_standards.sh`.


## Candles, responsive layout and Android integration tests (2026-11-08)

### Done and verified (host machine)
- Candle chart (ADR-0017) and phone/tablet layout (ADR-0018). `flutter analyze` clean, 489 unit/widget/contract tests green (incl. end-to-end widget tests at phone 412x915 and tablet 1000x1400), `tool/check_standards.sh` 0 violations.
- `integration_test/app_flow_test.dart` written (6 scenarios, adapts to phone/tablet).
- Tablet AVD `pulse_tablet` (Pixel Tablet, 2560x1600 @320dpi = 1280x800 dp) created from the installed Android 36 image.
- `android/settings.gradle.kts`: aligns every buildscript to AGP 8.11.1 because the Flutter SDK's `integration_test` plugin pins AGP 8.2.1, which is not in the offline Gradle cache.

### NOT done: integration tests have NOT run on any emulator
The Gradle build for the integration run fails in this environment at `:app:checkDebugAarMetadata`: `androidx.test:runner`, `androidx.test:rules` and `androidx.test.espresso:espresso-core` (required by the `integration_test` plugin) are not in the local Gradle cache and Google Maven is unreachable from this machine's network: `dl.google.com/dl/android/maven2/...` (and the `maven.google.com` redirect to it) answers HTTP 404 for every artifact, even for AGP versions that exist, while Maven Central and other hosts respond. Re-running with the sandbox disabled (user-approved) gave the identical result, so it is the network, not the sandbox The apparent egress country was FI (VPN on) and well-known artifacts such as `androidx.core:core:1.12.0` and AGP 8.11.1 still returned 404, so this is not a regional block; the endpoint itself is not serving Maven files from this machine. Unresolved: needs a network where Google Maven works, a pre-populated Gradle cache (`~/.gradle`) containing `androidx.test:{runner,rules}` and `espresso-core`, or an approved mirror. Android license acceptance (`flutter doctor --android-licenses`) is also pending and is the user's step.

Run on a machine with internet access:

```bash
# phone (already running as emulator-5554)
flutter test integration_test/app_flow_test.dart -d emulator-5554
# tablet
~/Documents/SDKAndroid/emulator/emulator -avd pulse_tablet &
flutter test integration_test/app_flow_test.dart -d emulator-5556   # use the id from `adb devices`
```


## Wallet home, orders, units, demo switch (2026-11-08)

### Done and verified (host machine + Android phone emulator, API 36)
- **Wallet home and bottom navigation** (ADR-0019): wallet / orders / search & add; holdings vs watchlist; stocks vs crypto; swipe-to-delete and drag-to-reorder (no Edit mode); Vazirmatn font; refreshed Material 3 theme.
- **Orders tab** (ADR-0020): history with status and asset-class dropdowns; rejected orders from a local log; **no cancel** (the fake API has none and must not be modified).
- **Units and availability** (ADR-0021): units shown everywhere; buy shows USD available and the max quantity, sell shows what can be sold; "max" button.
- **Candles:** the newest bar follows the live price (ADR-0017 amendment).
- **Demo and resilience** (ADR-0022): chaos switch in the app bar; instant "connection lost" banner; connection-count and teardown tests; a late-tick crash in `CandlesCubit` fixed.
- Messages and holdings texts reviewed; `pulse_api` was restored to its original state (an earlier edit broke the "do not modify" rule).

### Result
| Check | Result |
|---|---|
| `flutter analyze` | No issues |
| App tests | 548 passed |
| Standards-checker tests | 63 passed |
| Design-system tests | 41 passed |
| `tool/check_standards.sh` | 0 violations |

### Honest limitations
- Integration tests (`integration_test/`) still have **not** run on an emulator (Gradle/Maven problem above). The new screens were checked by hand on the phone emulator only; no tablet emulator run for the new home.
- Placing an order was exercised by tests, not by hand on the emulator after the latest changes.
- Coverage was not re-measured after these changes (last figure 94.7%).
- Rejected orders are device-local; `cancelled` and `pending` filters are empty with the current backend.
- The chaos switch ships in every build (Q17); server-driven UI values need a config endpoint (Q18).
- Open questions Q15..Q18 in [QUESTIONS.md](QUESTIONS.md) are assumed defaults awaiting the Tech Lead.

### Commits
- `feat: wallet home, orders, units, availability and demo chaos switch` (code and tests)
- `docs: add adrs 0019-0022 and update progress, questions and readme`

