import 'package:decimal/decimal.dart';

/// How much the user can still order, from the server's account figures.
abstract final class MaxOrderQuantity {
  /// Largest quantity (a multiple of [lotSize]) that [cash] pays for at
  /// [price]. Null when there is no usable price; zero when even one lot is
  /// too expensive.
  static Decimal? forBuy({
    required Decimal cash,
    required Decimal? price,
    required Decimal lotSize,
  }) {
    if (price == null || price <= Decimal.zero || lotSize <= Decimal.zero) {
      return null;
    }
    if (cash <= Decimal.zero) return Decimal.zero;
    final lots = (cash / (price * lotSize)).floor();
    return Decimal.fromBigInt(lots) * lotSize;
  }

  /// Largest quantity the user can sell: what they hold, rounded down to a
  /// multiple of [lotSize].
  static Decimal forSell({required Decimal held, required Decimal lotSize}) {
    if (held <= Decimal.zero || lotSize <= Decimal.zero) return Decimal.zero;
    final lots = (held / lotSize).floor();
    return Decimal.fromBigInt(lots) * lotSize;
  }
}
