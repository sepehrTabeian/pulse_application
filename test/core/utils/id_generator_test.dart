import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/utils/id_generator.dart';

void main() {
  final uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('generates RFC 4122 version 4 ids', () {
    final id = UuidV4Generator().generate();

    expect(id, matches(uuidV4));
  });

  test('generates unique ids across many calls', () {
    final generator = UuidV4Generator();

    final ids = {for (var i = 0; i < 2000; i++) generator.generate()};

    expect(ids.length, 2000);
  });

  test('is usable through the IdGenerator interface', () {
    final IdGenerator generator = UuidV4Generator();

    expect(generator.generate(), isNotEmpty);
  });
}
