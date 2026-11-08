import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/storage/key_value_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reads an empty list for an unknown key', () async {
    final store = SharedPreferencesKeyValueStore(
      await SharedPreferences.getInstance(),
    );

    expect(await store.readStringList('missing'), isEmpty);
  });

  test('writes and reads back a list, preserving order and unicode', () async {
    final store = SharedPreferencesKeyValueStore(
      await SharedPreferences.getInstance(),
    );

    await store.writeStringList('k', ['b', 'a', 'پالس', '']);

    expect(await store.readStringList('k'), ['b', 'a', 'پالس', '']);
  });

  test('writing again replaces the previous value', () async {
    final store = SharedPreferencesKeyValueStore(
      await SharedPreferences.getInstance(),
    );
    await store.writeStringList('k', ['1', '2']);

    await store.writeStringList('k', ['3']);

    expect(await store.readStringList('k'), ['3']);
  });

  test('data survives a new store instance on the same preferences', () async {
    final prefs = await SharedPreferences.getInstance();
    await SharedPreferencesKeyValueStore(prefs).writeStringList('k', ['x']);

    expect(await SharedPreferencesKeyValueStore(prefs).readStringList('k'), [
      'x',
    ]);
  });
}
