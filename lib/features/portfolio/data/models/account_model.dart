import 'package:decimal/decimal.dart';
import 'package:pulse/core/data/json/json_reader.dart';
import 'package:pulse/core/data/json/lenient.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/features/portfolio/domain/entities/account.dart';

class PositionModel {
  const PositionModel({this.symbol, this.quantity, this.averageCost});

  factory PositionModel.fromJson(JsonReader json) {
    return PositionModel(
      symbol: json.string('symbol'),
      quantity: json.decimal('quantity'),
      averageCost: json.decimal('averageCost'),
    );
  }

  final String? symbol;
  final Decimal? quantity;
  final Decimal? averageCost;

  Position toEntity() {
    final cleanSymbol = symbol?.trim();
    if (cleanSymbol == null || cleanSymbol.isEmpty) {
      throw const ParsingException(field: 'symbol', expectedType: 'string');
    }
    return Position(
      symbol: cleanSymbol,
      quantity: requireValue<Decimal>(quantity, 'quantity', 'decimal'),
      averageCost: averageCost,
    );
  }
}

class AccountModel {
  const AccountModel({this.currency, this.cash, this.positions});

  factory AccountModel.fromJson(JsonReader json) {
    return AccountModel(
      currency: json.string('currency'),
      cash: json.decimal('cash'),
      positions: json
          .objects('positions')
          ?.map(PositionModel.fromJson)
          .toList(),
    );
  }

  static const String _defaultCurrency = 'USD';

  final String? currency;
  final Decimal? cash;
  final List<PositionModel>? positions;

  /// Cash is required (a wrong "0" would mislead the user). Invalid
  /// positions are skipped and reported through [onSkipped].
  Account toEntity({SkipReporter? onSkipped}) {
    final cleanCurrency = currency?.trim();
    return Account(
      currency: cleanCurrency == null || cleanCurrency.isEmpty
          ? _defaultCurrency
          : cleanCurrency,
      cash: requireValue<Decimal>(cash, 'cash', 'decimal'),
      positions: mapLenient<PositionModel, Position>(
        positions ?? const <PositionModel>[],
        (p) => p.toEntity(),
        onSkipped: onSkipped,
      ),
    );
  }
}
