import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/local/holding_search_service.dart';
import '../../data/model/parcel.dart';
import '../../data/repo/holdings_reader.dart';
import 'parcel_search_state.dart';

/// Owns Home's transient query and results. Dataset changes are observed from
/// [HoldingsReader], so a detail/add/edit operation refreshes results without
/// a screen asking HomeCubit to reload itself.
class ParcelSearchCubit extends Cubit<ParcelSearchState> {
  ParcelSearchCubit(this._reader) : super(const ParcelSearchState()) {
    _subscription = _reader.snapshots.listen(_onSnapshot);
  }

  static const Duration debounceDuration = Duration(milliseconds: 180);

  final HoldingsReader _reader;
  late final StreamSubscription<List<Parcel>> _subscription;
  Timer? _debounce;

  void updateQuery(final String query) {
    _debounce?.cancel();
    _debounce = Timer(debounceDuration, () => _search(query));
  }

  void clear() {
    _debounce?.cancel();
    emit(const ParcelSearchState());
  }

  void _onSnapshot(final List<Parcel> _) {
    if (state.query.trim().isNotEmpty) _search(state.query);
  }

  void _search(final String query) {
    final String trimmed = query.trim();
    emit(
      ParcelSearchState(
        query: query,
        results:
            trimmed.isEmpty ? const <SearchResult>[] : _reader.search(query),
      ),
    );
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    await _subscription.cancel();
    return super.close();
  }
}
