import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

enum PriceDirection { up, down, flat }

/// Change of the last price vs previous close.
class PriceChange extends Equatable {
  const PriceChange({
    required this.absolute,
    required this.percent,
    required this.direction,
  });

  static const int _percentScale = 6;

  final Decimal absolute;
  final Decimal percent;
  final PriceDirection direction;

  /// Null when there is no usable previous close (never divides by zero).
  static PriceChange? compute({
    required Decimal last,
    required Decimal? prevClose,
  }) {
    if (prevClose == null || prevClose <= Decimal.zero) return null;
    final absolute = last - prevClose;
    final percent = (absolute * Decimal.fromInt(100) / prevClose).toDecimal(
      scaleOnInfinitePrecision: _percentScale,
    );
    final direction = switch (absolute.sign) {
      > 0 => PriceDirection.up,
      < 0 => PriceDirection.down,
      _ => PriceDirection.flat,
    };
    return PriceChange(
      absolute: absolute,
      percent: percent,
      direction: direction,
    );
  }

  @override
  List<Object?> get props => [absolute, percent, direction];
}
