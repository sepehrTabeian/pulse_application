# 0022. Demo chaos switch and resource-lifecycle guarantees
Date: 2026-11-08
Status: Accepted (Tech Lead, demo preparation)
Deciders: Tech Lead, Staff Flutter Engineer

## Context
The 15-minute demo must show a hostile network on demand, and reviewers will ask about leaks.

## Decision
- **Chaos switch:** a `Switch` (⚡) in the home app bar flips `api.chaos` between `ChaosConfig.realistic` and `ChaosConfig.storm` at runtime. The widget talks to a `ChaosController` interface (domain); `FakeApiChaosController` (core/data) is the only place that touches `FakeTradingApi` (LAYER-02). The app does not know about the switch: banner, reconnect and retries react by themselves.
- **Instant drop notice:** the status banner also shows the "connection lost, retrying" message as soon as the feed reports a reconnect, not only after the 6 s stale timer.
- **No leak:** the shared price feed keeps one connection. Tests (`test/app_resilience_test.dart`) assert `api.openConnectionCount == 1` at start, after tab changes, opening/closing the ticket and search, changing symbols, after repeated drops and recovery, and `0` after background and after unmounting.
- **Teardown:** on `AppLifecycleState.detached` the container is reset, which disposes the lazily created `FakeTradingApi` (all sockets and timers). A provided api is owned by its creator. A test asserts no connection, further calls fail, and (through flutter_test's pending-timer check) no timer survives.
- Late events: `CandlesCubit.applyLivePrice` ignores a tick that arrives after the cubit is closed (found by the lifecycle test).

## Consequences
+ The storm demo is one tap; leak claims are backed by assertions. − The switch is a demo control and ships in every build; hide it behind a flag for production.
