import 'package:pulse/features/portfolio/domain/entities/account.dart';

/// Reads cash and positions. Throws `AppException` subtypes.
abstract interface class AccountReader {
  Future<Account> getAccount();
}
