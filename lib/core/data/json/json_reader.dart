import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:pulse/core/errors/app_exception.dart';

/// Tolerant reader for untrusted JSON objects (PARSE-01..06).
///
/// Optional getters return `null` for missing keys, `null` values and wrong
/// types (normalising harmless drift such as numbers sent as strings). They
/// never throw. `require*` getters throw [ParsingException], never `TypeError`.
class JsonReader {
  const JsonReader._(this._map, this.path);

  /// Decodes [body] and requires the root to be a JSON object.
  factory JsonReader.parse(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (e, st) {
      throw ParsingException(
        field: r'$',
        expectedType: 'json',
        cause: e,
        stackTrace: st,
      );
    }
    return JsonReader.fromObject(decoded);
  }

  factory JsonReader.fromObject(Object? value, {String path = r'$'}) {
    final reader = tryFrom(value, path: path);
    if (reader == null) {
      throw ParsingException(
        field: path,
        expectedType: 'object',
        actualType: _typeName(value),
      );
    }
    return reader;
  }

  /// Returns a reader when [value] is a JSON object, otherwise `null`.
  static JsonReader? tryFrom(Object? value, {String path = r'$'}) {
    return value is Map<Object?, Object?> ? JsonReader._(value, path) : null;
  }

  /// Longest decimal text we are willing to parse (guards CPU/memory).
  static const int _maxDecimalLength = 40;

  final Map<Object?, Object?> _map;
  final String path;

  String? string(String key) {
    final value = _map[key];
    if (value is String) return value;
    if (value is num && (value is! double || value.isFinite)) {
      return value.toString();
    }
    return null;
  }

  String requireString(String key) {
    final value = string(key)?.trim();
    if (value == null || value.isEmpty) throw _missing(key, 'string');
    return value;
  }

  Decimal? decimal(String key) => _toDecimal(_map[key]);

  Decimal requireDecimal(String key) {
    return decimal(key) ?? (throw _missing(key, 'decimal'));
  }

  int? integer(String key) {
    final value = _map[key];
    if (value is int) return value;
    if (value is double &&
        value.isFinite &&
        value == value.truncateToDouble()) {
      return value.toInt();
    }
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  int requireInteger(String key) {
    return integer(key) ?? (throw _missing(key, 'integer'));
  }

  bool? boolean(String key) {
    final value = _map[key];
    if (value is bool) return value;
    if (value is String) {
      return switch (value.trim().toLowerCase()) {
        'true' => true,
        'false' => false,
        _ => null,
      };
    }
    if (value is int) {
      return switch (value) {
        1 => true,
        0 => false,
        _ => null,
      };
    }
    return null;
  }

  DateTime? dateTime(String key) {
    final value = _map[key];
    return value is String ? DateTime.tryParse(value.trim()) : null;
  }

  /// Object items of the list at [key]; non-object items are dropped.
  /// Returns `null` when the key is missing or not a list.
  List<JsonReader>? objects(String key) {
    final value = _map[key];
    if (value is! List<Object?>) return null;
    final result = <JsonReader>[];
    for (var i = 0; i < value.length; i++) {
      final item = tryFrom(value[i], path: '$path.$key[$i]');
      if (item != null) result.add(item);
    }
    return List.unmodifiable(result);
  }

  /// String items of the list at [key]; other items are dropped.
  List<String>? strings(String key) {
    final value = _map[key];
    if (value is! List<Object?>) return null;
    return List.unmodifiable(value.whereType<String>());
  }

  static Decimal? _toDecimal(Object? value) {
    if (value is int) return Decimal.fromInt(value);
    if (value is double) {
      return value.isFinite ? Decimal.tryParse(value.toString()) : null;
    }
    if (value is! String) return null;
    final text = value.trim();
    if (text.isEmpty || text.length > _maxDecimalLength) return null;
    if (text.contains('e') || text.contains('E')) return null;
    return Decimal.tryParse(text);
  }

  ParsingException _missing(String key, String expected) {
    return ParsingException(
      field: '$path.$key',
      expectedType: expected,
      actualType: _typeName(_map[key]),
    );
  }

  static String _typeName(Object? value) =>
      value == null ? 'null' : value.runtimeType.toString();
}
