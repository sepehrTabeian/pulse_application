import 'dart:async';

import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/errors/exception_mapper.dart';
import 'package:pulse/core/errors/retry_policy.dart';

/// Single place where remote failures become [AppException]s (ERR-01) and
/// where retry policy is applied (ERR-07).
class RemoteCallGuard {
  RemoteCallGuard({
    required ExceptionMapper mapper,
    required RetryPolicy retryPolicy,
  }) : _mapper = mapper,
       _retryPolicy = retryPolicy;

  final ExceptionMapper _mapper;
  final RetryPolicy _retryPolicy;

  /// For idempotent calls (reads, full-replace writes): retries retryable
  /// failures with backoff.
  Future<T> retrying<T>(Future<T> Function() call) {
    return _retryPolicy.run(() => once(call));
  }

  /// Exactly one attempt, never retried. Use for non-idempotent actions.
  Future<T> once<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AppException {
      rethrow;
      // Boundary catch (ERR-03): anything else is mapped, never swallowed.
    } on Object catch (error, stackTrace) {
      throw _mapper.map(error, stackTrace);
    }
  }

  /// Maps errors of a live stream; data events pass through untouched.
  Stream<T> guardStream<T>(Stream<T> source) {
    return source.transform(
      StreamTransformer<T, T>.fromHandlers(
        handleError: (error, stackTrace, sink) {
          sink.addError(_mapper.map(error, stackTrace), stackTrace);
        },
      ),
    );
  }
}
