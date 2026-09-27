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
    this.jazlaId,
    this.cityId,
  ) : super(const JazlaAddParcelState());

  final JazlaRepo _repo;
  final ParcelCatalogReader _holdingsReader;
  final JazlaSearchService _searchService;
  final String jazlaId;
  final String cityId;
  Timer? _debounce;
  Map<String, String> _jazlaNameByParcelId = <String, String>{};
  String? _preferredBasinName;
  bool _ownershipLoaded = false;

  Future<void> initializeOwnership() async {
    if (_ownershipLoaded) return;
    await refreshOwnership();
  }

  Future<void> refreshOwnership() async {
    final List<Jazla> all = await _repo.getAll(cityId);
    if (isClosed) return;
    _jazlaNameByParcelId = <String, String>{
      for (final Jazla j in all)
        for (final String id in j.parcelIds) id: j.name,
    };
    _preferredBasinName = _basinForCurrentJazla(all);
    _ownershipLoaded = true;
  }

  /// Keeps the search ranking aligned when the user changes this Jazla's
  /// basin from its action sheet. The active query is re-ranked in memory;
  /// no extra catalog or network read is needed.
  void setPreferredBasin(final String? basinName) {
    final String? normalized = basinName?.trim();
    final String? next = normalized?.isEmpty ?? true ? null : normalized;
    if (_preferredBasinName == next) return;
    _preferredBasinName = next;
    if (state.query.trim().isNotEmpty) _searchNow(state.query);
  }

  String? _basinForCurrentJazla(final List<Jazla> jazlas) {
    for (final Jazla jazla in jazlas) {
      if (jazla.id == jazlaId) return jazla.basinName?.trim();
    }
    return null;
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
      if (isClosed) return;
      final List<ParcelSearchResult> results = _searchService.search(
        _holdingsReader.parcels,
        query,
        _jazlaNameByParcelId,
        preferredBasinName: _preferredBasinName,
      );
      if (!isClosed && state.query == query) {
        emit(state.copyWith(
          status: JazlaAddParcelStatus.idle,
          results: results,
        ));
      }
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
          status: JazlaAddParcelStatus.error, errorMessage: e.toString()));
    }
  }

  void markParcelAdded(final String parcelId, final String jazlaName) {
    if (isClosed) return;
    _jazlaNameByParcelId = <String, String>{
      ..._jazlaNameByParcelId,
      parcelId: jazlaName,
    };
    _searchNow(state.query);
  }

  void markParcelRemoved(final String parcelId) {
    if (isClosed) return;
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
