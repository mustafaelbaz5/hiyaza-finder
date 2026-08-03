import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../cities/domain/entities/city.dart';
import '../../../cities/domain/entities/city_snapshot.dart';
import '../../../cities/domain/repositories/city_repository.dart';
import '../../../sync/presentation/cubit/sync_status_cubit.dart';
import '../../data/repository/holdings_repository.dart';
import '../../domain/entities/parcel.dart';
import '../services/holding_search_service.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._repository, this._cityRepository)
      : super(HomeState.initial());

  final HoldingsRepository _repository;
  final CityRepository _cityRepository;

  /// Metadata for the active city — `null` until one has been loaded.
  CitySnapshot? _activeCitySnapshot;

  Future<void> init() async {
    emit(state.copyWith(status: HomeStatus.loading));

    // App-start sync trigger — gives any operation still sitting in the
    // outbox from a previous session a chance to flush as soon as the app
    // is usable again, regardless of whether a cached city load below
    // succeeds. Fire-and-forget: `SyncStatusCubit.flushNow()` already
    // guards against overlap with every other trigger, and this screen's
    // own loading state must not wait on a network round-trip.
    unawaited(getIt<SyncStatusCubit>().flushNow());

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

  void search(final String query) {
    final List<SearchResult> results = query.trim().isEmpty
        ? const <SearchResult>[]
        : _repository.search(query, basin: state.selectedBasin);
    emit(state.copyWith(query: query, results: results));
  }

  /// Narrows subsequent searches to [basin] (اسم الحوض), or `null` to
  /// search the whole loaded dataset again.
  void selectBasin(final String? basin) {
    final List<SearchResult> results = state.query.trim().isEmpty
        ? const <SearchResult>[]
        : _repository.search(state.query, basin: basin);
    emit(state.copyWith(selectedBasin: basin, results: results));
  }
}
