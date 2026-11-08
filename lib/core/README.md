# `lib/core/`: cross-cutting code

Nothing here knows about a specific feature screen. Features depend on `core`; `core` never depends on a feature,
except the DI files, which are the composition root and may name every feature.

| Folder | What | Notes |
|---|---|---|
| `errors/` | `AppException` hierarchy (`ServerException`, `ClientException`, ...), `ErrorCodes`, `ExceptionMapper`, `RetryPolicy` | Errors are exceptions with stable codes, never strings (ADR-0016) |
| `data/errors/` | `PulseApiExceptionMapper` | Maps `ApiException`/`TimeoutException`/`ConnectionLostException` to `AppException` |
| `data/json/` | `JsonReader`, `mapLenient` | The ONLY place that reads untrusted JSON (rule: no `as` casts on external data). Decimal strings become `Decimal` |
| `data/remote/` | `TradingRemoteSource` (interface), `FakeTradingApiRemoteSource`, `RemoteCallGuard`, `FakeApiChaosController` | The seam to `pulse_api`. `RemoteCallGuard.once` = one attempt (orders); `.retrying` = bounded retries (reads) |
| `di/` | `injection.dart`, `trading_injection.dart`, `app_injection.dart` | get_it registration, idempotent. ONE `FakeTradingApi` per container, disposed with it |
| `format/` | `DecimalFormatter`, `NumberInput` | Latin digits, `,` grouping; `NumberInput` accepts Persian/Arabic digits, rejects a comma, max 8 decimals |
| `presentation/` | `ErrorMessageResolver`, `AdaptiveLayout` | Error to Persian message by code; phone vs tablet (two-pane) breakpoint |
| `storage/` | `KeyValueStore` (+ `SharedPreferencesKeyValueStore`) | Tiny persistence port; failures become `StorageException` |
| `logging/` | `AppLogger` | No `print` anywhere |
| `utils/` | `Clock`, `IdGenerator` | Injectable time and ids so tests can fake them |
| `bloc/` | `event_transformers.dart` | RxDart debounce used inside Bloc |
| `constants/` | `AppLimits` | Backend contract limits (watchlist max 20) |
| `l10n/` | `app_fa.arb` + `generated/` | Edit the ARB, run `flutter gen-l10n`. `generated/` is committed and never hand-edited |

## DI registration order

```
configureCoreDependencies(di)                    // logger, mapper, resolver, retry policy, id generator
configureTradingDependencies(di, {api})          // FakeTradingApi, remote source, guard, repositories (role interfaces)
configureAppDependencies(di, store: ...)         // use cases, services, blocs/cubits (factories)
```

Tests build their own `GetIt.asNewInstance()` and pass `api:` / `store:` fakes (see `test/support`).

## Rules of thumb

- A new network call goes through `RemoteCallGuard` and a repository in the feature's `data/`; the feature's `domain/`
  exposes a small role interface (ISP).
- A new user-facing error: add the code to `ErrorCodes`, the mapping in `ErrorMessageResolver`, the string in the ARB.
- Never format money outside `DecimalFormatter`.
