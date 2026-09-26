import 'package:equatable/equatable.dart';

import '../../data/local/holding_search_service.dart';

class ParcelSearchState extends Equatable {
  const ParcelSearchState({
    this.query = '',
    this.results = const <SearchResult>[],
  });

  final String query;
  final List<SearchResult> results;

  ParcelSearchState copyWith({
    final String? query,
    final List<SearchResult>? results,
  }) =>
      ParcelSearchState(
        query: query ?? this.query,
        results: results ?? this.results,
      );

  @override
  List<Object?> get props => <Object?>[query, results];
}
