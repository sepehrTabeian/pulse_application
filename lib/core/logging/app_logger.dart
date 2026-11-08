import 'dart:developer' as developer;

/// Logging abstraction (ERR-06). Never log secrets or personal data.
abstract interface class AppLogger {
  void debug(String message);
  void info(String message);
  void warn(String message, {Object? error, StackTrace? stackTrace});
  void error(String message, {Object? error, StackTrace? stackTrace});
}

class DeveloperLogger implements AppLogger {
  static const String _name = 'pulse';
  static const int _debug = 500;
  static const int _info = 800;
  static const int _warn = 900;
  static const int _error = 1000;

  @override
  void debug(String message) =>
      developer.log(message, name: _name, level: _debug);

  @override
  void info(String message) =>
      developer.log(message, name: _name, level: _info);

  @override
  void warn(String message, {Object? error, StackTrace? stackTrace}) =>
      developer.log(
        message,
        name: _name,
        level: _warn,
        error: error,
        stackTrace: stackTrace,
      );

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      developer.log(
        message,
        name: _name,
        level: _error,
        error: error,
        stackTrace: stackTrace,
      );
}
