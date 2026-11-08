import 'package:flutter/material.dart';

/// Round badge with the first letters of a symbol, tinted by [tone]. Stands
/// in for a logo (Trust-Wallet style asset list).
class PulseAssetAvatar extends StatelessWidget {
  const PulseAssetAvatar({
    required this.symbol,
    required this.tone,
    this.size = 44,
    super.key,
  });

  final String symbol;
  final Color tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letters = symbol.split('-').first;
    final shown = letters.length > 3 ? letters.substring(0, 3) : letters;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tone.withValues(alpha: 0.16),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            shown,
            maxLines: 1,
            style: TextStyle(
              color: tone,
              fontWeight: FontWeight.w700,
              fontSize: size * (shown.length > 2 ? 0.28 : 0.34),
            ),
          ),
        ),
      ),
    );
  }
}
