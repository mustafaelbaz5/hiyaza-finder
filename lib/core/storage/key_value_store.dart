import 'package:shared_preferences/shared_preferences.dart';

/// Abstraction over simple string-keyed persistence, so every data source
/// that needs on-device key/value storage depends on this interface instead
/// of calling `SharedPreferences.getInstance()` directly. This is the only
/// file that may import `shared_preferences`.
abstract class KeyValueStore {
  Future<String?> getString(final String key);
  Future<void> setString(final String key, final String value);
  Future<void> remove(final String key);
}

class SharedPreferencesKeyValueStore implements KeyValueStore {
  const SharedPreferencesKeyValueStore();

  @override
  Future<String?> getString(final String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> setString(final String key, final String value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Future<void> remove(final String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
