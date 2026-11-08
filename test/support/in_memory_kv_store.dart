import 'package:pulse/core/errors/app_exception.dart';
import 'package:pulse/core/storage/key_value_store.dart';

class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, List<String>> data = {};
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<List<String>> readStringList(String key) async {
    if (failReads) throw const StorageException();
    return List.of(data[key] ?? const <String>[]);
  }

  @override
  Future<void> writeStringList(String key, List<String> value) async {
    if (failWrites) throw const StorageException();
    data[key] = List.of(value);
  }
}
