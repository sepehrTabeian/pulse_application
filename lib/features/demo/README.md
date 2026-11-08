# demo

Controls used only for the live demo. ADR-0022.

- `domain/chaos_controller.dart`: `ChaosController` (`isStorm`, `setStorm`).
- `core/data/remote/fake_api_chaos_controller.dart`: the implementation; the only code that sets `api.chaos`.
- `presentation/chaos_switch.dart`: the ⚡ switch in the home app bar. Flips the shared fake server between
  `ChaosConfig.realistic` and `ChaosConfig.storm` at runtime. The app does not know about the switch: the banner, the
  reconnects and the retries just react.

The switch ships in every build (open question Q17). To hide it for production, stop passing it in `AppRoot`
(`appBarActions`) or guard it with a flag.

Tests: `test/app_resilience_test.dart` (flips, storm warnings, recovery, connection count).
