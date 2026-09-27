import 'package:equatable/equatable.dart';

import '../../../parcel_catalog/data/model/parcel.dart';

class JazlaReviewState extends Equatable {
  const JazlaReviewState({
    required this.parcels,
    required this.index,
    this.isSaving = false,
  });

  final List<Parcel> parcels;
  final int index;
  final bool isSaving;

  Parcel get parcel => parcels[index];
  bool get canGoPrevious => index > 0;
  bool get canGoNext => index < parcels.length - 1;

  JazlaReviewState copyWith({
    final List<Parcel>? parcels,
    final int? index,
    final bool? isSaving,
  }) =>
      JazlaReviewState(
        parcels: parcels ?? this.parcels,
        index: index ?? this.index,
        isSaving: isSaving ?? this.isSaving,
      );

  @override
  List<Object?> get props => <Object?>[parcels, index, isSaving];
}
