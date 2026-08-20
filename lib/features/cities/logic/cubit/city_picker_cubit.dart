import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hiyaza_finder/features/holdings/data/repo/holdings_repository.dart';

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

  Future<void> loadCities() async {
    if (isClosed) return;
    emit(state.copyWith(status: CityPickerStatus.loading));
    try {
      final List<City> cities = await _cityRepository.listPublishedCities();
      if (isClosed) return;
      emit(state.copyWith(status: CityPickerStatus.loaded, cities: cities));
    } on AppException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CityPickerStatus.error,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CityPickerStatus.error,
          errorMessage: e.toString(),
        ),
      );
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
      final CitySnapshot snapshot = await _cityRepository.downloadCity(city);
      await _holdingsRepository.loadParcelsForCity(
        snapshot.cityId,
        snapshot.parcels,
        cityName: snapshot.cityName,
        directorate: snapshot.directorate,
        administration: snapshot.administration,
        associationType: snapshot.associationType,
        associationSubtype: snapshot.associationSubtype,
      );
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
