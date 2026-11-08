import 'package:pulse/core/constants/limits.dart';
import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/error_codes.dart';

/// Pure list edits with the same rules the server enforces (VAL-04), so a
/// request that would be rejected is never sent. Every method returns a NEW
/// list and throws a `ValidationException` or `BusinessRuleException`.
class WatchlistRules {
  const WatchlistRules({this.maxSymbols = AppLimits.watchlistMaxSymbols});

  final int maxSymbols;

  List<String> add(List<String> symbols, String symbol) {
    final clean = symbol.trim();
    if (clean.isEmpty) {
      throw const ValidationException(field: 'symbol', rule: 'required');
    }
    if (symbols.contains(clean)) {
      throw const ValidationException(field: 'symbol', rule: 'duplicate');
    }
    if (symbols.length >= maxSymbols) {
      throw const BusinessRuleException(code: ErrorCodes.watchlistFull);
    }
    return List.unmodifiable([...symbols, clean]);
  }

  List<String> remove(List<String> symbols, String symbol) {
    return List.unmodifiable(symbols.where((s) => s != symbol));
  }

  /// Moves the item at [oldIndex] so it ends at [newIndex] in the FINAL list
  /// (not Flutter's "insert before" index; callers adjust).
  List<String> move(List<String> symbols, int oldIndex, int newIndex) {
    final inRange =
        oldIndex >= 0 &&
        oldIndex < symbols.length &&
        newIndex >= 0 &&
        newIndex < symbols.length;
    if (!inRange) {
      throw const ValidationException(field: 'index', rule: 'out_of_range');
    }
    final copy = [...symbols];
    final item = copy.removeAt(oldIndex);
    copy.insert(newIndex, item);
    return List.unmodifiable(copy);
  }
}
