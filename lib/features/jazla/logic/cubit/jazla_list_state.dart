import 'package:equatable/equatable.dart';

import '../../data/model/jazla.dart';

enum JazlaListStatus { loading, loaded, error }

class JazlaListState extends Equatable {
  const JazlaListState({
    required this.status,
    this.jazlas = const <Jazla>[],
    this.errorMessage,
  });

  factory JazlaListState.initial() =>
      const JazlaListState(status: JazlaListStatus.loading);

  final JazlaListStatus status;
  final List<Jazla> jazlas;
  final String? errorMessage;

  JazlaListState copyWith({
    final JazlaListStatus? status,
    final List<Jazla>? jazlas,
    final String? errorMessage,
  }) =>
      JazlaListState(
        status: status ?? this.status,
        jazlas: jazlas ?? this.jazlas,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => <Object?>[status, jazlas, errorMessage];
}
