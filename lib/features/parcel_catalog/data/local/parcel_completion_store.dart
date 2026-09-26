import 'dart:convert';

import '../../../../core/storage/key_value_store.dart';

class ParcelCompletionStatus {
  const ParcelCompletionStatus({required this.completedAt, this.completedBy});

  final DateTime completedAt;
  final String? completedBy;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'completedAt': completedAt.toIso8601String(),
        'completedBy': completedBy,
      };

  static ParcelCompletionStatus? fromJson(final dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    final String? rawDate = value['completedAt'] as String?;
    final DateTime? date = rawDate == null ? null : DateTime.tryParse(rawDate);
    if (date == null) return null;
    return ParcelCompletionStatus(
      completedAt: date,
      completedBy: value['completedBy'] as String?,
    );
  }
}

class ParcelCompletionStore {
  ParcelCompletionStore({
    final KeyValueStore store = const SharedPreferencesKeyValueStore(),
  }) : _store = store;

  final KeyValueStore _store;
  final Map<String, Map<String, ParcelCompletionStatus>> _cache =
      <String, Map<String, ParcelCompletionStatus>>{};

  static String _key(final String cityId) =>
      'parcel_completion_status::$cityId';

  Future<Map<String, ParcelCompletionStatus>> load(final String cityId) async {
    final Map<String, ParcelCompletionStatus>? cached = _cache[cityId];
    if (cached != null) return Map<String, ParcelCompletionStatus>.of(cached);

    final String? raw = await _store.getString(_key(cityId));
    if (raw == null || raw.isEmpty) {
      _cache[cityId] = <String, ParcelCompletionStatus>{};
      return <String, ParcelCompletionStatus>{};
    }

    final Map<String, dynamic> decoded =
        jsonDecode(raw) as Map<String, dynamic>;
    final Map<String, ParcelCompletionStatus> result =
        <String, ParcelCompletionStatus>{};
    for (final MapEntry<String, dynamic> entry in decoded.entries) {
      final ParcelCompletionStatus? status =
          ParcelCompletionStatus.fromJson(entry.value);
      if (status != null) result[entry.key] = status;
    }
    _cache[cityId] = result;
    return Map<String, ParcelCompletionStatus>.of(result);
  }

  Future<void> saveCompleted(
    final String cityId,
    final String parcelId,
    final ParcelCompletionStatus status,
  ) async {
    final Map<String, ParcelCompletionStatus> current = await _cached(cityId);
    current[parcelId] = status;
    _cache[cityId] = current;
    await _persist(cityId, current);
  }

  Future<void> remove(final String cityId, final String parcelId) async {
    final Map<String, ParcelCompletionStatus> current = await _cached(cityId);
    if (current.remove(parcelId) == null) return;
    _cache[cityId] = current;
    await _persist(cityId, current);
  }

  Future<void> renameParcelId(
    final String cityId,
    final String oldId,
    final String newId,
  ) async {
    final Map<String, ParcelCompletionStatus> current = await _cached(cityId);
    final ParcelCompletionStatus? status = current.remove(oldId);
    if (status == null) return;
    current[newId] = status;
    _cache[cityId] = current;
    await _persist(cityId, current);
  }

  Future<Map<String, ParcelCompletionStatus>> _cached(
    final String cityId,
  ) async {
    final Map<String, ParcelCompletionStatus>? cached = _cache[cityId];
    if (cached != null) return Map<String, ParcelCompletionStatus>.of(cached);
    return load(cityId);
  }

  Future<void> _persist(
    final String cityId,
    final Map<String, ParcelCompletionStatus> statuses,
  ) async {
    if (statuses.isEmpty) {
      await _store.remove(_key(cityId));
      return;
    }
    await _store.setString(
      _key(cityId),
      jsonEncode(statuses.map(
        (final String id, final ParcelCompletionStatus status) =>
            MapEntry<String, dynamic>(id, status.toJson()),
      )),
    );
  }
}
