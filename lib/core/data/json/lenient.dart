import 'package:pulse/core/errors/app_exception.dart';

/// Reports one item skipped while mapping a list (PARSE-05).
typedef SkipReporter = void Function(ParsingException error);

/// Maps [items], skipping (and reporting) the ones that fail to convert, so a
/// single bad element never discards the whole list.
List<T> mapLenient<S, T>(
  Iterable<S> items,
  T Function(S item) convert, {
  SkipReporter? onSkipped,
}) {
  final result = <T>[];
  for (final item in items) {
    try {
      result.add(convert(item));
    } on ParsingException catch (e) {
      onSkipped?.call(e);
    }
  }
  return List.unmodifiable(result);
}

/// Returns [value] or throws [ParsingException] naming [field].
T requireValue<T extends Object>(T? value, String field, String expected) {
  return value ??
      (throw ParsingException(
        field: field,
        expectedType: expected,
        actualType: 'null',
      ));
}
