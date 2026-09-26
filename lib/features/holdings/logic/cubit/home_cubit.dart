import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/local/holding_search_service.dart';
import '../../data/model/parcel.dart';
import '../../data/repo/holdings_reader.dart';
import '../../data/repo/parcel_catalog_session.dart';

import '../../../cities/data/model/city_snapshot.dart';
import '../../../cities/data/repo/city_repo.dart';

import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._session, this._reader, this._cityRepository)
      : super(HomeState.initial());

  final ParcelCatalogSession _session;
  final HoldingsReader _reader;
  final CityRepo _cityRepository;

  /// Metadata for the active city — `null` until one has been loaded.
  CitySnapshot? _activeCitySnapshot;
  late final StreamSubscription<List<Parcel>> _snapshotSubscription =
      _reader.snapshots.listen(_onSnapshot);

  void _onSnapshot(final List<Parcel> parcels) {
    if (isClosed || state.status != HomeStatus.loaded) return;
    emit(
      state.copyWith(
        parcels: parcels,
        results: state.query.trim().isEmpty
            ? const <SearchResult>[]
            : _reader.search(state.query),
        modifiedIds: _modifiedIds(parcels),
      ),
    );
  }

  Future<void> init() async {
    emit(state.copyWith(status: HomeStatus.loading));

    final CitySnapshot? cached = await _tryLoadCachedCity();
    if (cached != null) {
      _activeCitySnapshot = cached;
      emit(_loadedState(_reader.parcels));
      return;
    }

    emit(state.copyWith(status: HomeStatus.noFile));
  }

  Future<CitySnapshot?> _tryLoadCachedCity() async {
    try {
      final CitySnapshot? snapshot =
          await _cityRepository.loadActiveCachedSnapshot();
      if (snapshot == null) return null;
      await _session.loadParcelsForCity(
        snapshot.cityId,
        snapshot.parcels,
        cityName: snapshot.cityName,
        directorate: snapshot.directorate,
        administration: snapshot.administration,
        associationType: snapshot.associationType,
        associationSubtype: snapshot.associationSubtype,
        basins: snapshot.basins,
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
    emit(_loadedState(_reader.parcels));
  }

  /// Re-reads the active city's dataset from the repository — a local-only
  /// reload, e.g. after returning from a screen that mutated parcels
  /// directly on the repository. Re-downloading is only ever done
  /// explicitly from the city picker, never automatically from here.
  void refreshActiveCity() {
    if (_activeCitySnapshot == null) return;
    refreshData();
  }

  HomeState _loadedState(final List<Parcel> parcels) {
    return state.copyWith(
      status: HomeStatus.loaded,
      parcels: parcels,
      query: '',
      results: const <SearchResult>[],
      modifiedIds: _modifiedIds(parcels),
    );
  }

  /// Which of [parcels] have a local edit-overlay entry — backs
  /// `HomeState.modifiedCount`.
  Set<String> _modifiedIds(final List<Parcel> parcels) => <String>{
        for (final Parcel p in parcels)
          if (_reader.isParcelEdited(p.id)) p.id,
      };

  /// Re-derives state from the repository's current data — used after
  /// returning from a screen that mutated parcels directly on the
  /// repository (e.g. the bulk-edit/file-status screen, or the Basin/
  /// Detail screens' writes), since that mutates the same underlying list
  /// in place without going through this cubit.
  void refreshData() {
    final List<Parcel> parcels = _reader.parcels;
    emit(
      state.copyWith(
        parcels: parcels,
        results: state.query.trim().isEmpty
            ? state.results
            : _reader.search(state.query),
        modifiedIds: _modifiedIds(parcels),
      ),
    );
  }

  /// Searches the whole active dataset (every basin) — the home screen's
  /// search bar always searches globally regardless of which basin cards
  /// are showing below it.
  void search(final String query) {
    final List<SearchResult> results =
        query.trim().isEmpty ? const <SearchResult>[] : _reader.search(query);
    emit(state.copyWith(query: query, results: results));
  }

  @override
  Future<void> close() async {
    await _snapshotSubscription.cancel();
    return super.close();
  }
}
