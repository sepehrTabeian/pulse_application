import 'package:pulse/core/logging/app_logger.dart';

/// Test double for [AppLogger] that records every call.
class RecordingLogger implements AppLogger {
  final List<String> entries = [];

  @override
  void debug(String message) => entries.add('debug:$message');

  @override
  void info(String message) => entries.add('info:$message');

  @override
  void warn(String message, {Object? error, StackTrace? stackTrace}) =>
      entries.add('warn:$message');

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      entries.add('error:$message');
}
