import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/logging/app_logger.dart';

void main() {
  test('DeveloperLogger never throws for any level or null error', () {
    final logger = DeveloperLogger();

    expect(() {
      logger.debug('d');
      logger.info('i');
      logger.warn('w');
      logger.warn('w', error: 'e', stackTrace: StackTrace.current);
      logger.error('e');
      logger.error('e', error: Exception('x'), stackTrace: StackTrace.current);
    }, returnsNormally);
  });

  test('accepts empty and very long messages', () {
    final logger = DeveloperLogger();

    expect(() {
      logger.info('');
      logger.info('x' * 100000);
    }, returnsNormally);
  });
}
