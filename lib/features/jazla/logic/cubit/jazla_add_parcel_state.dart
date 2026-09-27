import 'package:equatable/equatable.dart';

import '../../data/local/jazla_search_service.dart';

enum JazlaAddParcelStatus { idle, searching, error }

class JazlaAddParcelState extends Equatable {
  const JazlaAddParcelState({
    this.status = JazlaAddParcelStatus.idle,
    this.query = '',
    this.results = const <ParcelSearchResult>[],
    this.errorMessage,
  });

  final JazlaAddParcelStatus status;
  final String query;
  final List<ParcelSearchResult> results;
  final String? errorMessage;

  JazlaAddParcelState copyWith({
    final JazlaAddParcelStatus? status,
    final String? query,
    final List<ParcelSearchResult>? results,
    final String? errorMessage,
  }) =>
      JazlaAddParcelState(
        status: status ?? this.status,
        query: query ?? this.query,
        results: results ?? this.results,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => <Object?>[status, query, results, errorMessage];
}
