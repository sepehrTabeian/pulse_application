/// Demo control over how hostile the (fake) server behaves. The app never
/// learns about the switch: banners, reconnects and retries just react.
abstract interface class ChaosController {
  /// True while the server runs in its hostile "storm" mode.
  bool get isStorm;

  /// Switches between the realistic and the storm profile.
  void setStorm({required bool enabled});
}
