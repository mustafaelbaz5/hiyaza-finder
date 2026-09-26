import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../parcel_catalog/data/model/parcel.dart';
import '../../../parcel_catalog/data/repo/holdings_reader.dart';
import 'basins_state.dart';

/// Owns the basin overview state and reacts to parcel catalog mutations.
class BasinsCubit extends Cubit<BasinsState> {
  BasinsCubit(this._reader)
      : super(BasinsState(basins: List.unmodifiable(_reader.basinSummaries))) {
    _subscription = _reader.snapshots.listen((final _) => _emitCurrentBasins());
  }

  final ParcelCatalogReader _reader;
  late final StreamSubscription<List<Parcel>> _subscription;

  void _emitCurrentBasins() => emit(
        BasinsState(basins: List.unmodifiable(_reader.basinSummaries)),
      );

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
