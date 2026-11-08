/// Spacing, radius and motion tokens. Replaceable by designer tokens later.
abstract final class PulseSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Minimum interactive target (CODE-07).
  static const double minTouchTarget = 48;
}

abstract final class PulseRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
}

abstract final class PulseMotion {
  static const Duration priceFlash = Duration(milliseconds: 400);
  static const Duration short = Duration(milliseconds: 150);
}
