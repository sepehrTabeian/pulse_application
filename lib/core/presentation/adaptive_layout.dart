import 'package:flutter/widgets.dart';

/// Window classes (Material 3 guidance: compact < 600 dp wide). Two panes
/// need both enough width AND enough height, so a phone in landscape
/// (wide but short) keeps the single-pane layout.
abstract final class AdaptiveLayout {
  static const double minTwoPaneWidth = 600;
  static const double minTwoPaneHeight = 480;

  /// Fixed width of the list pane in the two-pane layout.
  static const double listPaneWidth = 380;

  /// Content never stretches wider than this inside the detail pane.
  static const double maxDetailContentWidth = 640;

  static bool isTwoPane(Size size) =>
      size.width >= minTwoPaneWidth && size.height >= minTwoPaneHeight;

  static bool isTwoPaneOf(BuildContext context) =>
      isTwoPane(MediaQuery.sizeOf(context));
}
