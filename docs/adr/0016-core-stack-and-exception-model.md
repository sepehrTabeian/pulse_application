# 0016. Core stack, Clean Architecture and exception model
Date: 2026-11-08
Status: Accepted (mandated by the Tech Lead in CODING_STANDARDS.md)
Deciders: Tech Lead, Staff Flutter Engineer

## Decision
- **Architecture:** Clean Architecture per feature (`domain` pure Dart, `data`, `presentation`); dependency rule enforced by `tool/check_standards.sh` (`LAYER-*`).
- **State:** Bloc/Cubit; Bloc where event transformers matter (order flow = `droppable`, search = RxDart `debounceRestartable`).
- **DI:** get_it, composition roots only (`core/di/*`); blocs/cubits are factories; one `FakeTradingApi` per app.
- **No code generation** for models/logic (ADR-0001); hand-written `JsonReader`, models, equality.
- **Errors:** exceptions only. `AppException` interface → `ServerException` / `ClientException` families; a single `ExceptionMapper` in the data layer converts `ApiException`, `TimeoutException`, `ConnectionLostException`, `FormatException` and unknown errors; UI text comes from a localized `ErrorMessageResolver`, never from raw server messages. `RequestTimeoutException` means "outcome unknown", never "failed".
- **SOLID/ISP:** small role interfaces (`OrderPlacer` vs `OrderLookup`, `WatchlistReader` vs `WatchlistWriter`, ...).
- **Money:** `Decimal` everywhere, never `double`.

## Consequences
Testable, explainable layers; every rule has an ID that the checker reports.
