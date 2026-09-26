import 'package:equatable/equatable.dart';

import '../../../parcel_catalog/data/model/basin_progress.dart';

/// Immutable render state for the basin overview.
class BasinsState extends Equatable {
  const BasinsState({this.basins = const <BasinProgress>[]});

  final List<BasinProgress> basins;

  bool get isEmpty => basins.isEmpty;

  @override
  List<Object?> get props => <Object?>[basins];
}
