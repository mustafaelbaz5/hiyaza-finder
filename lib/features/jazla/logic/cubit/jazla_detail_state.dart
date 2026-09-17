import 'package:equatable/equatable.dart';

import '../../../holdings/data/model/parcel.dart';
import '../../data/model/jazla.dart';

enum JazlaDetailStatus { loading, loaded, error, notFound }

class JazlaDetailState extends Equatable {
  const JazlaDetailState({
    required this.status,
    this.jazla,
    this.parcels = const <Parcel>[],
    this.errorMessage,
  });

  factory JazlaDetailState.initial() =>
      const JazlaDetailState(status: JazlaDetailStatus.loading);

  final JazlaDetailStatus status;
  final Jazla? jazla;
  final List<Parcel> parcels;
  final String? errorMessage;

  JazlaDetailState copyWith({
    final JazlaDetailStatus? status,
    final Jazla? jazla,
    final List<Parcel>? parcels,
    final String? errorMessage,
  }) =>
      JazlaDetailState(
        status: status ?? this.status,
        jazla: jazla ?? this.jazla,
        parcels: parcels ?? this.parcels,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => <Object?>[status, jazla, parcels, errorMessage];
}
