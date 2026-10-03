import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../parcel_catalog/data/local/parcel_visibility_preferences.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../../../parcel_catalog/data/model/parcel_visibility_filter.dart';
import '../../../parcel_catalog/data/model/search_result.dart';
import '../../../parcel_catalog/data/repo/holdings_reader.dart';
import 'parcel_search_state.dart';

/// Owns Home's transient query, its activity filter, and results.
///
/// The catalog keeps immutable activity indexes, so switching visibility or
/// receiving a local parcel update never performs a remote request.
class ParcelSearchCubit extends Cubit<ParcelSearchState> {
  ParcelSearchCubit(
    this._reader, {
    final ParcelVisibilityPreferences preferences =
        const ParcelVisibilityPreferences(),
  })  : _preferences = preferences,
        super(const ParcelSearchState()) {
    _subscription = _reader.snapshots.listen(_onSnapshot);
  }

  static const Duration debounceDuration = Duration(milliseconds: 180);

  final ParcelCatalogReader _reader;
  final ParcelVisibilityPreferences _preferences;
  late final StreamSubscription<List<Parcel>> _subscription;
  Timer? _debounce;
  String? _preferenceCityId;

  void updateQuery(final String query) {
    _debounce?.cancel();
    _debounce = Timer(debounceDuration, () => _search(query));
  }

  void clear() {
    _debounce?.cancel();
    emit(
      ParcelSearchState(
        visibility: state.visibility,
      ),
    );
  }

  Future<void> selectVisibility(final ParcelVisibilityFilter visibility) async {
    if (visibility == state.visibility) return;
    emit(state.copyWith(visibility: visibility));
    _search(state.query);

    final String? cityId = _reader.activeCityId;
    if (cityId == null) return;
    try {
      await _preferences.save(cityId, visibility);
    } catch (_) {
      // A failed preference write should never block search or discard the
      // visible filter. The next city load simply falls back to active-only.
    }
  }

  void showZeroAreaMatches() =>
      selectVisibility(ParcelVisibilityFilter.zeroAreaOnly);

  void _onSnapshot(final List<Parcel> _) {
    final String? cityId = _reader.activeCityId;
    if (cityId != null && cityId != _preferenceCityId) {
      _preferenceCityId = cityId;
      unawaited(_restoreCityPreference(cityId));
      return;
    }
    if (state.query.trim().isNotEmpty) _search(state.query);
  }

  Future<void> _restoreCityPreference(final String cityId) async {
    ParcelVisibilityFilter visibility = ParcelVisibilityFilter.activeOnly;
    try {
      visibility = await _preferences.load(cityId);
    } catch (_) {
      // The default active-only view remains usable when local preferences
      // are unavailable or corrupt.
    }
    if (isClosed || _reader.activeCityId != cityId) return;
    emit(state.copyWith(visibility: visibility));
    if (state.query.trim().isNotEmpty) _search(state.query);
  }

  void _search(final String query) {
    if (isClosed) return;
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      emit(
        ParcelSearchState(
          visibility: state.visibility,
        ),
      );
      return;
    }

    final List<SearchResult> results = _reader.search(
      query,
      visibility: state.visibility,
    );
    final int hiddenZeroAreaMatches =
        state.visibility == ParcelVisibilityFilter.activeOnly
            ? _reader
                .search(
                  query,
                  visibility: ParcelVisibilityFilter.zeroAreaOnly,
                )
                .length
            : 0;

    emit(
      ParcelSearchState(
        query: query,
        results: results,
        visibility: state.visibility,
        zeroAreaMatchCount: hiddenZeroAreaMatches,
      ),
    );
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    await _subscription.cancel();
    return super.close();
  }
}
