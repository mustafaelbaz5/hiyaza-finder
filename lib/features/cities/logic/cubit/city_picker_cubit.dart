import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../holdings/data/repo/holdings_repository.dart';

import '../../../../core/errors/exceptions.dart';

import '../../data/model/city.dart';
import '../../data/model/city_snapshot.dart';
import '../../data/repo/city_repo.dart';
import 'city_state.dart';

/// Lists downloadable (`published`) cities and hands a picked city's
/// downloaded dataset to [HoldingsRepository] so the rest of the app (which
/// only knows about `HoldingsRepository`/`Parcel`, not Supabase) can use it
/// immediately without a restart.
class CityPickerCubit extends Cubit<CityPickerState> {
  CityPickerCubit(this._cityRepository, this._holdingsRepository)
      : super(CityPickerState.initial());

  final CityRepo _cityRepository;
  final HoldingsRepository _holdingsRepository;
  bool _initialized = false;
  Future<void>? _initialization;

  Future<void> initialize() {
    if (_initialization != null) return _initialization!;
    _initialization = _initialize();
    return _initialization!;
  }

  Future<void> _initialize() async {
    if (_initialized || isClosed) return;
    _initialized = true;
    try {
      final List<City> cached =
          await _cityRepository.loadCachedPublishedCities();
      final Set<String> cachedCityIds = await _cachedCityIds();
      if (cached.isNotEmpty && !isClosed) {
        emit(state.copyWith(
          status: CityPickerStatus.loaded,
          cities: cached,
          cachedCityIds: cachedCityIds,
        ));
      }
    } catch (_) {
      // A broken catalog must not prevent the remote refresh below.
    }
    await refreshCities();
  }

  Future<void> loadCities() => refreshCities();

  Future<void> refreshCities() async {
    if (isClosed) return;
    final bool hasVisibleCities = state.cities.isNotEmpty;
    emit(state.copyWith(
      status:
          hasVisibleCities ? CityPickerStatus.loaded : CityPickerStatus.loading,
      isRefreshing: true,
      errorMessage: null,
    ));
    try {
      final List<City> cities = await _cityRepository.listPublishedCities();
      try {
        await _cityRepository.savePublishedCities(cities);
      } catch (_) {
        // A catalog-cache failure must not hide a successful remote response.
      }
      final Set<String> cachedCityIds = await _cachedCityIds();
      if (isClosed) return;
      emit(state.copyWith(
        status: CityPickerStatus.loaded,
        cities: cities,
        cachedCityIds: cachedCityIds,
        isRefreshing: false,
      ));
    } on AppException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CityPickerStatus.error,
          errorMessage: e.message,
          isRefreshing: false,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CityPickerStatus.error,
          errorMessage: e.toString(),
          isRefreshing: false,
        ),
      );
    }
  }

  Future<Set<String>> _cachedCityIds() async {
    try {
      return (await _cityRepository.listCachedCities())
          .map((final meta) => meta.cityId)
          .toSet();
    } catch (_) {
      return state.cachedCityIds;
    }
  }

  /// Downloads [city]'s dataset and makes it the active one. Returns the
  /// resulting snapshot (`null` on failure) — the screen awaits this
  /// directly (rather than listening for a state change) and pops with it
  /// on success, matching how `confirmAssociationName`/similar one-shot
  /// actions are already awaited elsewhere in this codebase.
  Future<CitySnapshot?> downloadAndActivate(final City city) async {
    if (isClosed) return null;
    emit(state.copyWith(status: CityPickerStatus.downloading));
    try {
      final CitySnapshot snapshot =
          await _cityRepository.loadCachedCity(city.id) ??
              await _cityRepository.downloadCity(city);
      await _cityRepository.activateCachedCity(snapshot.cityId);
      await _holdingsRepository.loadParcelsForCity(
        snapshot.cityId,
        snapshot.parcels,
        cityName: snapshot.cityName,
        directorate: snapshot.directorate,
        administration: snapshot.administration,
        associationType: snapshot.associationType,
        associationSubtype: snapshot.associationSubtype,
        basins: snapshot.basins,
      );
      if (!isClosed && !state.cachedCityIds.contains(city.id)) {
        emit(state.copyWith(
          status: CityPickerStatus.loaded,
          cachedCityIds: <String>{...state.cachedCityIds, city.id},
        ));
      }
      return snapshot;
    } on AppException catch (e) {
      if (isClosed) return null;
      emit(
        state.copyWith(
            status: CityPickerStatus.loaded, errorMessage: e.message),
      );
      return null;
    } catch (e) {
      if (isClosed) return null;
      emit(
        state.copyWith(
          status: CityPickerStatus.loaded,
          errorMessage: e.toString(),
        ),
      );
      return null;
    }
  }
}
