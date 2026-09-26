import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../parcel_catalog/data/local/holding_search_service.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../../../parcel_catalog/data/repo/holdings_reader.dart';
import '../../data/model/basin_holding_filter.dart';
import 'basin_holdings_state.dart';

/// Derives the groups and completion filter for one basin from the catalog.
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
    emit(_buildState(filter: filter));
  }

  List<Parcel> parcelsFor(final String groupKey) =>
      state.groupsByKey[groupKey] ?? const <Parcel>[];

  void _emitForCurrentCatalog() => emit(_buildState(filter: state.filter));

  BasinHoldingsState _buildState({required final BasinHoldingFilter filter}) {
    final List<Parcel> basinParcels = _reader.parcels
        .where((final Parcel parcel) => parcel.basinName == state.basinName)
        .toList(growable: false);
    final Map<String, List<Parcel>> groups = <String, List<Parcel>>{};
    for (final Parcel parcel in basinParcels) {
      (groups[parcel.groupKey] ??= <Parcel>[]).add(parcel);
    }
    final List<SearchResult> allResults = groups.entries
        .map((final MapEntry<String, List<Parcel>> entry) {
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
    }).toList()
      ..sort((final SearchResult left, final SearchResult right) =>
          _holdingNumberValue(left.holdingId)
              .compareTo(_holdingNumberValue(right.holdingId)));

    final List<SearchResult> visibleResults = switch (filter) {
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
      basinParcels: List.unmodifiable(basinParcels),
      allResults: List.unmodifiable(allResults),
      visibleResults: List.unmodifiable(visibleResults),
      groupsByKey: Map.unmodifiable(
        groups.map((final String key, final List<Parcel> value) =>
            MapEntry<String, List<Parcel>>(key, List.unmodifiable(value))),
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
