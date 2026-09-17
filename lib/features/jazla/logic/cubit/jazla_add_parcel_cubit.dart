import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../holdings/data/model/parcel.dart';
import '../../../holdings/data/repo/holdings_reader.dart';
import '../../data/local/jazla_search_service.dart';
import '../../data/model/jazla.dart';
import '../../data/repo/jazla_repo.dart';
import 'jazla_add_parcel_state.dart';

class JazlaAddParcelCubit extends Cubit<JazlaAddParcelState> {
  JazlaAddParcelCubit(
    this._repo,
    this._holdingsReader,
    this._searchService,
    this.jazlaId,
    this.cityId,
  ) : super(const JazlaAddParcelState());

  final JazlaRepo _repo;
  final HoldingsReader _holdingsReader;
  final JazlaSearchService _searchService;
  final String jazlaId;
  final String cityId;

  Future<Map<String, String>> _jazlaNameByParcelId() async {
    final List<Jazla> all = await _repo.getAll(cityId);
    return <String, String>{
      for (final Jazla j in all)
        for (final String id in j.parcelIds) id: j.name,
    };
  }

  Future<void> search(final String query) async {
    emit(state.copyWith(status: JazlaAddParcelStatus.searching, query: query));
    try {
      final Map<String, String> jazlaNameByParcelId = await _jazlaNameByParcelId();
      final List<ParcelSearchResult> results = _searchService.search(
        _holdingsReader.parcels,
        query,
        jazlaNameByParcelId,
      );
      emit(state.copyWith(status: JazlaAddParcelStatus.idle, results: results));
    } catch (e) {
      emit(state.copyWith(status: JazlaAddParcelStatus.error, errorMessage: e.toString()));
    }
  }

  /// Adds a free parcel to this Jazla. Rejects before any repo call if the
  /// current in-memory results already show it locked — `JazlaRepo.addParcel`
  /// is still the authority (it throws `CacheException` if used), this is
  /// just a fast client-side guard against the obvious case.
  Future<void> addFreeParcel(final String parcelId) async {
    final ParcelSearchResult? match = state.results
        .where((final ParcelSearchResult r) => r.parcel.id == parcelId)
        .firstOrNull;
    if (match != null && match.isLocked) return;

    emit(state.copyWith(status: JazlaAddParcelStatus.adding));
    try {
      await _repo.addParcel(jazlaId, parcelId, cityId);
      emit(
        state.copyWith(
          status: JazlaAddParcelStatus.idle,
          lastAddedParcelId: parcelId,
        ),
      );
      await search(state.query);
    } on AppException catch (e) {
      emit(state.copyWith(status: JazlaAddParcelStatus.error, errorMessage: e.message));
    }
  }

  /// Called when the reused add-person/add-parcel-for-existing-person flow
  /// returns a newly created [Parcel] — auto-adds it to this Jazla.
  Future<void> onExternalParcelCreated(final Parcel parcel) => addFreeParcel(parcel.id);
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
