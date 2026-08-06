import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../cities/domain/entities/city.dart';
import '../../../cities/domain/entities/city_snapshot.dart';
import '../../../cities/domain/repositories/city_repository.dart';
import '../../data/repository/holdings_repository.dart';
import '../../domain/entities/parcel.dart';
import '../../domain/services/holding_search_service.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._repository, this._cityRepository)
      : super(HomeState.initial()) {
    // `_repository` is a singleton and outlives any single `HomeCubit`
    // instance (this cubit is recreated per navigation, see
    // `app_router.dart`) — a Realtime event applied via
    // `HoldingsRepository.applyRemoteChange` while this screen is on
    // screen wouldn't otherwise be noticed, since it mutates the
    // repository's list in place without going through this cubit.
    _remoteChangesSub = _repository.onRemoteChange.listen((final _) => refreshData());
  }

  final HoldingsRepository _repository;
  final CityRepository _cityRepository;
  late final StreamSubscription<void> _remoteChangesSub;

  /// Metadata for the active city — `null` until one has been loaded.
  CitySnapshot? _activeCitySnapshot;

  Future<void> init() async {
    emit(state.copyWith(status: HomeStatus.loading));

    final CitySnapshot? cached = await _tryLoadCachedCity();
    if (cached != null) {
      _activeCitySnapshot = cached;
      emit(_loadedState(_repository.parcels));
      unawaited(_checkStaleness());
      return;
    }

    emit(state.copyWith(status: HomeStatus.noFile));
  }

  Future<CitySnapshot?> _tryLoadCachedCity() async {
    try {
      final CitySnapshot? snapshot =
          await _cityRepository.loadActiveCachedSnapshot();
      if (snapshot == null) return null;
      await _repository.loadParcelsForCity(
        snapshot.cityId,
        snapshot.parcels,
        cityName: snapshot.cityName,
        directorate: snapshot.directorate,
        administration: snapshot.administration,
        associationType: snapshot.associationType,
        associationSubtype: snapshot.associationSubtype,
      );
      return snapshot;
    } catch (_) {
      // A corrupt/unreadable cache file should look like "nothing loaded
      // yet", not an error — the city picker is always available to
      // re-download from.
      return null;
    }
  }

  /// Adopts whatever `HoldingsRepository` currently holds as the loaded
  /// dataset — called after returning from the city picker, which
  /// downloads straight into the repository via `loadParcelsForCity`.
  void loadFromDownloadedCity(final CitySnapshot snapshot) {
    _activeCitySnapshot = snapshot;
    emit(_loadedState(_repository.parcels));
  }

  Future<void> _checkStaleness() async {
    final CitySnapshot? snapshot = _activeCitySnapshot;
    if (snapshot == null) return;
    try {
      final int remoteVersion =
          await _cityRepository.remoteDataVersion(snapshot.cityId);
      if (remoteVersion > snapshot.dataVersion) {
        emit(state.copyWith(isCityDataStale: true));
      }
    } catch (_) {
      // Offline, or the request failed — staleness is a courtesy notice,
      // not worth surfacing an error for.
    }
  }

  /// Re-downloads the active city and adopts the fresh data — the
  /// staleness banner's "تحديث البيانات" action and pull-to-refresh.
  /// Deliberately keeps `status: loaded` throughout and rethrows on
  /// failure instead of switching to `HomeStatus.loading`/`error`: those
  /// would swap out the entire loaded screen (fighting a pull gesture's
  /// own spinner, or discarding a perfectly working offline session over
  /// a transient refresh failure). Callers decide how to surface the
  /// error (e.g. a snackbar) while the current data stays on screen.
  Future<void> refreshActiveCity() async {
    final CitySnapshot? current = _activeCitySnapshot;
    if (current == null) return;

    final int remoteVersion =
        await _cityRepository.remoteDataVersion(current.cityId);
    final CitySnapshot fresh = await _cityRepository.downloadCity(
      City(
        id: current.cityId,
        name: current.cityName,
        status: CityStatus.published,
        dataVersion: remoteVersion,
        // `CityRepositoryImpl.downloadCity` copies these straight from the
        // `City` passed in — it does NOT re-fetch the `cities` row itself
        // (only `downloadHoldings` for parcels) — so without carrying them
        // forward from the cached snapshot here, a refresh would silently
        // wipe them from the new snapshot.
        directorate: current.directorate,
        administration: current.administration,
        associationType: current.associationType,
        associationSubtype: current.associationSubtype,
      ),
    );
    await _repository.loadParcelsForCity(
      fresh.cityId,
      fresh.parcels,
      cityName: fresh.cityName,
      directorate: fresh.directorate,
      administration: fresh.administration,
      associationType: fresh.associationType,
      associationSubtype: fresh.associationSubtype,
    );
    _activeCitySnapshot = fresh;
    emit(state.copyWith(isCityDataStale: false));
    refreshData();
  }

  HomeState _loadedState(final List<Parcel> parcels) {
    return state.copyWith(
      status: HomeStatus.loaded,
      parcels: parcels,
      query: '',
      results: const <SearchResult>[],
      availableBasins: _repository.availableBasins,
      selectedBasin: null,
      isCityDataStale: false,
    );
  }

  /// Re-derives state from the repository's current data — used after
  /// returning from a screen that mutated parcels directly on the
  /// repository (e.g. the bulk-edit/file-status screen), since that
  /// mutates the same underlying list in place without going through the
  /// cubit, so Bloc's equality check wouldn't otherwise notice the change.
  void refreshData() {
    emit(
      state.copyWith(
        parcels: _repository.parcels,
        availableBasins: _repository.availableBasins,
        results: state.query.trim().isEmpty
            ? state.results
            : _repository.search(state.query, basin: state.selectedBasin),
      ),
    );
  }

  /// Search token guarding [_mergeRemoteResults] — incremented on every call
  /// so a slow remote reply for a stale query can never overwrite the
  /// results of a newer one the user has since typed (`REFACTOR_ROADMAP.md`
  /// Phase 9 #7).
  int _searchToken = 0;

  void search(final String query) {
    final int token = ++_searchToken;
    final List<SearchResult> results = query.trim().isEmpty
        ? const <SearchResult>[]
        : _repository.search(query, basin: state.selectedBasin);
    emit(state.copyWith(query: query, results: results));
    if (query.trim().isNotEmpty) unawaited(_mergeRemoteResults(query, token));
  }

  /// Fires the live-DB follow-up search and, once it returns, merges any
  /// results the local cache missed into [HomeState.results] — additive
  /// only, never replaces what local search already found
  /// (`HoldingsRepository.searchRemote`'s own doc). No-op if a newer search
  /// has started since this call ([_searchToken] no longer matches), or if
  /// the query/basin has changed underneath it while awaiting.
  Future<void> _mergeRemoteResults(final String query, final int token) async {
    final List<SearchResult> remote =
        await _repository.searchRemote(query, state.results);
    if (token != _searchToken || remote.isEmpty) return;
    if (state.query != query) return;
    emit(state.copyWith(results: <SearchResult>[...state.results, ...remote]));
  }

  /// Narrows subsequent searches to [basin] (اسم الحوض), or `null` to
  /// search the whole loaded dataset again.
  void selectBasin(final String? basin) {
    final List<SearchResult> results = state.query.trim().isEmpty
        ? const <SearchResult>[]
        : _repository.search(state.query, basin: basin);
    emit(state.copyWith(selectedBasin: basin, results: results));
  }

  @override
  Future<void> close() {
    _remoteChangesSub.cancel();
    return super.close();
  }
}
