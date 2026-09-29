import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../parcel_catalog/data/local/holding_search_service.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../../../parcel_catalog/data/model/parcel_visibility_filter.dart';
import '../../../parcel_catalog/data/repo/holdings_reader.dart';
import '../../data/model/basin_holding_filter.dart';
import 'basin_holdings_state.dart';

/// Owns one basin's review and activity visibility filters.
class BasinHoldingsCubit extends Cubit<BasinHoldingsState> {
  BasinHoldingsCubit(this._reader, {required final String basinName})
      : super(BasinHoldingsState(basinName: basinName)) {
    _emitForCurrentCatalog();
    _subscription =
        _reader.snapshots.listen((final _) => _emitForCurrentCatalog());
  }

  final ParcelCatalogReader _reader;
  late final StreamSubscription<List<Parcel>> _subscription;

  void selectFilter(final BasinHoldingFilter filter) {
    if (filter == state.filter) return;
    emit(_buildState(filter: filter, visibility: state.visibility));
  }

  void selectVisibility(final ParcelVisibilityFilter visibility) {
    if (visibility == state.visibility) return;
    emit(_buildState(filter: state.filter, visibility: visibility));
  }

  List<Parcel> parcelsFor(final String groupKey) =>
      state.groupsByKey[groupKey] ?? const <Parcel>[];

  void _emitForCurrentCatalog() =>
      emit(_buildState(filter: state.filter, visibility: state.visibility));

  BasinHoldingsState _buildState({
    required final BasinHoldingFilter filter,
    required final ParcelVisibilityFilter visibility,
  }) {
    final List<Parcel> basinParcels = _reader.parcelsForVisibility(
      ParcelVisibilityFilter.all,
      basinName: state.basinName,
    );
    final List<Parcel> visibleParcels = _reader.parcelsForVisibility(
      visibility,
      basinName: state.basinName,
    );
    final Map<String, List<Parcel>> groups = <String, List<Parcel>>{};
    for (final Parcel parcel in visibleParcels) {
      (groups[parcel.groupKey] ??= <Parcel>[]).add(parcel);
    }
    final List<SearchResult> allResults = groups.entries.map(
      (final MapEntry<String, List<Parcel>> entry) {
        final List<Parcel> group = entry.value;
        final Parcel first = group.first;
        return SearchResult(
          holdingId: first.holdingId,
          groupKey: entry.key,
          holderName: first.holderName,
          parcelCount: group.length,
          score: 0,
          completedCount: group
              .where((final Parcel parcel) => parcel.completedAt != null)
              .length,
          isFieldAdded: first.isFieldAdded,
        );
      },
    ).toList()
      ..sort((final SearchResult left, final SearchResult right) =>
          _holdingNumberValue(left.holdingId)
              .compareTo(_holdingNumberValue(right.holdingId)));

    final List<SearchResult> results = switch (filter) {
      BasinHoldingFilter.all => allResults,
      BasinHoldingFilter.pending => allResults
          .where((final SearchResult result) =>
              result.completedCount < result.parcelCount)
          .toList(),
      BasinHoldingFilter.completed => allResults
          .where((final SearchResult result) =>
              result.parcelCount > 0 &&
              result.completedCount >= result.parcelCount)
          .toList(),
    };

    return BasinHoldingsState(
      basinName: state.basinName,
      basin: _reader.basinByName(state.basinName),
      filter: filter,
      visibility: visibility,
      activitySummary: _reader.activitySummaryForBasin(state.basinName),
      basinParcels: List<Parcel>.unmodifiable(basinParcels),
      visibleBasinParcels: List<Parcel>.unmodifiable(visibleParcels),
      allResults: List<SearchResult>.unmodifiable(allResults),
      visibleResults: List<SearchResult>.unmodifiable(results),
      groupsByKey: Map<String, List<Parcel>>.unmodifiable(
        groups.map((final String key, final List<Parcel> value) =>
            MapEntry<String, List<Parcel>>(
                key, List<Parcel>.unmodifiable(value))),
      ),
    );
  }

  double _holdingNumberValue(final String holdingId) =>
      double.tryParse(holdingId.trim()) ?? double.infinity;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
