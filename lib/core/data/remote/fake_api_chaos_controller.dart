import 'package:pulse/features/demo/domain/chaos_controller.dart';
import 'package:pulse_api/pulse_api.dart';

/// Flips the ONE shared [FakeTradingApi] between `ChaosConfig.realistic` and
/// `ChaosConfig.storm` at runtime.
class FakeApiChaosController implements ChaosController {
  const FakeApiChaosController(this._api);

  final FakeTradingApi _api;

  @override
  bool get isStorm => identical(_api.chaos, ChaosConfig.storm);

  @override
  void setStorm({required bool enabled}) {
    _api.chaos = enabled ? ChaosConfig.storm : ChaosConfig.realistic;
  }
}
