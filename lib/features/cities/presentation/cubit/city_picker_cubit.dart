import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../holdings/data/repository/holdings_repository.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/city_snapshot.dart';
import '../../domain/repositories/city_repository.dart';
import 'city_state.dart';

/// Lists downloadable (`published`) cities and hands a picked city's
/// downloaded dataset to [HoldingsRepository] so the rest of the app (which
/// only knows about `HoldingsRepository`/`Parcel`, not Supabase) can use it
/// immediately without a restart.
class CityPickerCubit extends Cubit<CityPickerState> {
  CityPickerCubit(this._cityRepository, this._holdingsRepository)
      : super(CityPickerState.initial());

  final CityRepository _cityRepository;
  final HoldingsRepository _holdingsRepository;

  Future<void> loadCities() async {
    emit(state.copyWith(status: CityPickerStatus.loading));
    try {
      final List<City> cities = await _cityRepository.listPublishedCities();
      emit(state.copyWith(status: CityPickerStatus.loaded, cities: cities));
    } on AppException catch (e) {
      emit(
        state.copyWith(
          status: CityPickerStatus.error,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
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
    emit(state.copyWith(status: CityPickerStatus.downloading));
    try {
      final CitySnapshot snapshot = await _cityRepository.downloadCity(city);
      await _holdingsRepository.loadParcelsForCity(
        snapshot.cityId,
        snapshot.parcels,
      );
      return snapshot;
    } on AppException catch (e) {
      emit(
        state.copyWith(status: CityPickerStatus.loaded, errorMessage: e.message),
      );
      return null;
    } catch (e) {
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
