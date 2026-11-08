import 'package:pulse/core/errors/app_exception.dart';

/// Converts any thrown object into an [AppException] (ERR-01).
abstract interface class ExceptionMapper {
  AppException map(Object error, [StackTrace? stackTrace]);
}
