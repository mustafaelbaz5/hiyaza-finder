import 'package:equatable/equatable.dart';

import '../../data/local/jazla_search_service.dart';

enum JazlaAddParcelStatus { idle, searching, adding, error }

class JazlaAddParcelState extends Equatable {
  const JazlaAddParcelState({
    this.status = JazlaAddParcelStatus.idle,
    this.query = '',
    this.results = const <ParcelSearchResult>[],
    this.errorMessage,
    this.lastAddedParcelId,
  });

  final JazlaAddParcelStatus status;
  final String query;
  final List<ParcelSearchResult> results;
  final String? errorMessage;

  /// Set (transiently) right after a successful add, so the sheet can show
  /// a confirmation without needing a separate one-shot event stream.
  final String? lastAddedParcelId;

  JazlaAddParcelState copyWith({
    final JazlaAddParcelStatus? status,
    final String? query,
    final List<ParcelSearchResult>? results,
    final String? errorMessage,
    final String? lastAddedParcelId,
  }) =>
      JazlaAddParcelState(
        status: status ?? this.status,
        query: query ?? this.query,
        results: results ?? this.results,
        errorMessage: errorMessage,
        lastAddedParcelId: lastAddedParcelId,
      );

  @override
  List<Object?> get props =>
      <Object?>[status, query, results, errorMessage, lastAddedParcelId];
}
