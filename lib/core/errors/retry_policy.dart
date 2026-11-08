import 'dart:math';

import 'package:pulse/core/errors/app_exception.dart';

/// Bounded exponential backoff with jitter (ERR-07). Retries only exceptions
/// whose [AppException.isRetryable] is true; everything else propagates.
class RetryPolicy {
  RetryPolicy({
    this.maxAttempts = 4,
    this.baseDelay = const Duration(milliseconds: 250),
    this.maxDelay = const Duration(seconds: 4),
    Random? random,
  }) : assert(maxAttempts >= 1, 'maxAttempts must be >= 1'),
       _random = random ?? Random();

  static const int _maxExponent = 20;
  static const double _jitterFactor = 0.5;

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final Random _random;

  /// Delay before retrying after failed [attempt] (1-based).
  Duration delayFor(int attempt) {
    final exponent = min(max(attempt, 1) - 1, _maxExponent);
    final capped = min(
      baseDelay.inMicroseconds * (1 << exponent),
      maxDelay.inMicroseconds,
    );
    final jitter = (capped * _jitterFactor * _random.nextDouble()).round();
    return Duration(
      microseconds: min(capped + jitter, maxDelay.inMicroseconds),
    );
  }

  Future<T> run<T>(
    Future<T> Function() action, {
    void Function(int attempt, AppException error)? onRetry,
  }) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return await action();
      } on AppException catch (e) {
        if (!e.isRetryable || attempt >= maxAttempts) rethrow;
        onRetry?.call(attempt, e);
        await Future<void>.delayed(delayFor(attempt));
      }
    }
  }
}
