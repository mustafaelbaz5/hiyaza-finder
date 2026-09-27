import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../parcel_catalog/data/repo/holdings_reader.dart';
import '../../data/local/jazla_search_service.dart';
import '../../data/model/jazla.dart';
import '../../data/repo/jazla_repo.dart';
import 'jazla_add_parcel_state.dart';

class JazlaAddParcelCubit extends Cubit<JazlaAddParcelState> {
  JazlaAddParcelCubit(
    this._repo,
    this._holdingsReader,
    this._searchService,
    this.cityId,
  ) : super(const JazlaAddParcelState());

  final JazlaRepo _repo;
  final ParcelCatalogReader _holdingsReader;
  final JazlaSearchService _searchService;
  final String cityId;
  Timer? _debounce;
  Map<String, String> _jazlaNameByParcelId = <String, String>{};
  bool _ownershipLoaded = false;

  Future<void> initializeOwnership() async {
    if (_ownershipLoaded) return;
    await refreshOwnership();
  }

  Future<void> refreshOwnership() async {
    final List<Jazla> all = await _repo.getAll(cityId);
    _jazlaNameByParcelId = <String, String>{
      for (final Jazla j in all)
        for (final String id in j.parcelIds) id: j.name,
    };
    _ownershipLoaded = true;
  }

  /// The ownership map is loaded once for the search session. Filtering the
  /// in-memory city catalog is then debounced, so typing never performs a
  /// Jazla-store read per keystroke.
  void search(final String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      emit(state.copyWith(
        status: JazlaAddParcelStatus.idle,
        query: query,
        results: const <ParcelSearchResult>[],
      ));
      return;
    }
    emit(state.copyWith(status: JazlaAddParcelStatus.searching, query: query));
    _debounce = Timer(const Duration(milliseconds: 180), () {
      _searchNow(query);
    });
  }

  Future<void> _searchNow(final String query) async {
    if (query.trim().isEmpty) return;
    try {
      await initializeOwnership();
      final List<ParcelSearchResult> results = _searchService.search(
        _holdingsReader.parcels,
        query,
        _jazlaNameByParcelId,
      );
      if (state.query == query) {
        emit(state.copyWith(
          status: JazlaAddParcelStatus.idle,
          results: results,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
          status: JazlaAddParcelStatus.error, errorMessage: e.toString()));
    }
  }

  void markParcelAdded(final String parcelId, final String jazlaName) {
    _jazlaNameByParcelId = <String, String>{
      ..._jazlaNameByParcelId,
      parcelId: jazlaName,
    };
    _searchNow(state.query);
  }

  void markParcelRemoved(final String parcelId) {
    _jazlaNameByParcelId = <String, String>{..._jazlaNameByParcelId}
      ..remove(parcelId);
    _searchNow(state.query);
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
