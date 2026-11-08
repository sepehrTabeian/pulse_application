import 'package:pulse/core/errors/app_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal persistence port (DIP). Failures surface as [StorageException].
abstract interface class KeyValueStore {
  Future<List<String>> readStringList(String key);
  Future<void> writeStringList(String key, List<String> value);
}

class SharedPreferencesKeyValueStore implements KeyValueStore {
  const SharedPreferencesKeyValueStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<List<String>> readStringList(String key) async {
    try {
      return _prefs.getStringList(key) ?? const <String>[];
    } on Object catch (e, st) {
      // Boundary catch (ERR-03): plugin errors become StorageException.
      throw StorageException(cause: e, stackTrace: st);
    }
  }

  @override
  Future<void> writeStringList(String key, List<String> value) async {
    try {
      final ok = await _prefs.setStringList(key, value);
      if (!ok) throw const StorageException();
    } on StorageException {
      rethrow;
    } on Object catch (e, st) {
      throw StorageException(cause: e, stackTrace: st);
    }
  }
}
