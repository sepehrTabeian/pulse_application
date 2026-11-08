import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('PulseTheme', () {
    test('light theme uses Material 3 and light brightness', () {
      final theme = PulseTheme.light();

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
    });

    test('dark theme uses dark brightness', () {
      expect(PulseTheme.dark().brightness, Brightness.dark);
    });

    test('both themes expose semantic colors extension', () {
      expect(
        PulseTheme.light().extension<PulseSemanticColors>(),
        PulseSemanticColors.light,
      );
      expect(
        PulseTheme.dark().extension<PulseSemanticColors>(),
        PulseSemanticColors.dark,
      );
    });

    test('price colors keep >= 3:1 contrast on surface in light mode', () {
      final theme = PulseTheme.light();
      const colors = PulseSemanticColors.light;

      for (final color in [colors.priceUp, colors.priceDown, colors.stale]) {
        expect(_contrast(color, theme.colorScheme.surface), greaterThan(3));
      }
    });

    test('price colors keep >= 3:1 contrast on surface in dark mode', () {
      final theme = PulseTheme.dark();
      const colors = PulseSemanticColors.dark;

      for (final color in [colors.priceUp, colors.priceDown, colors.stale]) {
        expect(_contrast(color, theme.colorScheme.surface), greaterThan(3));
      }
    });
  });

  group('PulseSemanticColors', () {
    test('lerp with unrelated extension returns this', () {
      const colors = PulseSemanticColors.light;

      expect(colors.lerp(null, 0.5), colors);
    });

    test('lerp at 0 and 1 returns endpoints', () {
      const a = PulseSemanticColors.light;
      const b = PulseSemanticColors.dark;

      expect(a.lerp(b, 0).priceUp, a.priceUp);
      expect(a.lerp(b, 1).priceUp, b.priceUp);
    });

    test('copyWith replaces only given fields', () {
      const base = PulseSemanticColors.light;

      final changed = base.copyWith(priceUp: const Color(0xFF000000));

      expect(changed.priceUp, const Color(0xFF000000));
      expect(changed.priceDown, base.priceDown);
    });
  });

  group('PulseSpacing', () {
    test('touch target meets 48dp minimum', () {
      expect(PulseSpacing.minTouchTarget, greaterThanOrEqualTo(48));
    });
  });
}
