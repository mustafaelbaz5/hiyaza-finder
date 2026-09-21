import 'package:equatable/equatable.dart';

import '../../data/model/jazla.dart';
import '../../data/local/jazla_preferences.dart';

enum JazlaListStatus { loading, loaded, error }

class JazlaListState extends Equatable {
  const JazlaListState({
    required this.status,
    this.jazlas = const <Jazla>[],
    this.errorMessage,
    this.sort = JazlaSort.newest,
  });

  factory JazlaListState.initial() =>
      const JazlaListState(status: JazlaListStatus.loading);

  final JazlaListStatus status;
  final List<Jazla> jazlas;
  final String? errorMessage;
  final JazlaSort sort;

  JazlaListState copyWith({
    final JazlaListStatus? status,
    final List<Jazla>? jazlas,
    final String? errorMessage,
    final JazlaSort? sort,
  }) =>
      JazlaListState(
        status: status ?? this.status,
        jazlas: jazlas ?? this.jazlas,
      errorMessage: errorMessage,
      sort: sort ?? this.sort,
      );

  @override
  List<Object?> get props => <Object?>[status, jazlas, errorMessage, sort];
}
