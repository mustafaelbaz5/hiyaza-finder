import '../../../../core/storage/key_value_store.dart';
import '../model/parcel_visibility_filter.dart';

/// City-scoped preference for Home search visibility.
class ParcelVisibilityPreferences {
  const ParcelVisibilityPreferences({
    final KeyValueStore store = const SharedPreferencesKeyValueStore(),
  }) : _store = store;

  static const String _keyPrefix = 'parcel_visibility_filter::';
  final KeyValueStore _store;

  Future<ParcelVisibilityFilter> load(final String cityId) async {
    final String? raw = await _store.getString('$_keyPrefix$cityId');
    return ParcelVisibilityFilter.values.firstWhere(
      (final ParcelVisibilityFilter filter) => filter.name == raw,
      orElse: () => ParcelVisibilityFilter.activeOnly,
    );
  }

  Future<void> save(
    final String cityId,
    final ParcelVisibilityFilter filter,
  ) =>
      _store.setString('$_keyPrefix$cityId', filter.name);
}
