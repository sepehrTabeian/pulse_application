import 'package:flutter/material.dart';

/// Semantic colors that Material 3 does not provide (price direction, stale,
/// halted). Feature code must use these instead of raw `Colors.*` (DS-04).
@immutable
class PulseSemanticColors extends ThemeExtension<PulseSemanticColors> {
  const PulseSemanticColors({
    required this.priceUp,
    required this.priceDown,
    required this.stale,
    required this.halted,
    required this.crypto,
  });

  static const PulseSemanticColors light = PulseSemanticColors(
    priceUp: Color(0xFF1B7F3B),
    priceDown: Color(0xFFB3261E),
    stale: Color(0xFF6B6B6B),
    halted: Color(0xFF8A5A00),
    crypto: Color(0xFFD97706),
  );

  static const PulseSemanticColors dark = PulseSemanticColors(
    priceUp: Color(0xFF7DDC8F),
    priceDown: Color(0xFFFFB4AB),
    stale: Color(0xFFB0B0B0),
    halted: Color(0xFFFFC857),
    crypto: Color(0xFFFFB454),
  );

  final Color priceUp;
  final Color priceDown;
  final Color stale;
  final Color halted;

  /// Accent of crypto assets (avatar), distinct from the stock accent.
  final Color crypto;

  @override
  PulseSemanticColors copyWith({
    Color? priceUp,
    Color? priceDown,
    Color? stale,
    Color? halted,
    Color? crypto,
  }) {
    return PulseSemanticColors(
      priceUp: priceUp ?? this.priceUp,
      priceDown: priceDown ?? this.priceDown,
      stale: stale ?? this.stale,
      halted: halted ?? this.halted,
      crypto: crypto ?? this.crypto,
    );
  }

  @override
  PulseSemanticColors lerp(
    covariant ThemeExtension<PulseSemanticColors>? other,
    double t,
  ) {
    if (other is! PulseSemanticColors) return this;
    return PulseSemanticColors(
      priceUp: Color.lerp(priceUp, other.priceUp, t) ?? priceUp,
      priceDown: Color.lerp(priceDown, other.priceDown, t) ?? priceDown,
      stale: Color.lerp(stale, other.stale, t) ?? stale,
      halted: Color.lerp(halted, other.halted, t) ?? halted,
      crypto: Color.lerp(crypto, other.crypto, t) ?? crypto,
    );
  }
}
