import 'package:uuid/uuid.dart';

/// Source of unique ids (e.g. order `clientOrderId`), injectable for tests.
abstract interface class IdGenerator {
  String generate();
}

class UuidV4Generator implements IdGenerator {
  UuidV4Generator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String generate() => _uuid.v4();
}
