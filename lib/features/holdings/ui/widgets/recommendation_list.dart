import 'package:flutter/material.dart';

import '../../data/local/holding_search_service.dart';
import 'home_no_results.dart';
import 'recommendation_tile.dart';

class RecommendationList extends StatelessWidget {
  const RecommendationList({
    super.key,
    required this.query,
    required this.results,
    required this.onSelect,
    this.onAddNew,
  });

  final String query;
  final List<SearchResult> results;
  final void Function(SearchResult result) onSelect;

  /// Offers "إضافة بيانات جديدة" on the no-results state. Always provided
  /// in practice today (this list only ever builds once a city is
  /// loaded), kept nullable so a future "no active city" state can still
  /// hide the CTA without a call-site change.
  final VoidCallback? onAddNew;

  static const ScrollPhysics _scrollPhysics = AlwaysScrollableScrollPhysics();

  @override
  Widget build(final BuildContext context) {
    if (results.isEmpty) {
      // `ListView`'s children stack at their intrinsic height rather than
      // stretching to fill the viewport, so a bare `Center` wouldn't
      // actually center — constrain it to at least the available height
      // first.
      return LayoutBuilder(
        builder:
            (final BuildContext context, final BoxConstraints constraints) {
          return ListView(
            physics: _scrollPhysics,
            padding: const EdgeInsets.symmetric(vertical: 24),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: HomeNoResults(query: query, onAddNew: onAddNew),
              ),
            ],
          );
        },
      );
    }

    return ListView.builder(
      physics: _scrollPhysics,
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: results.length,
      itemBuilder: (final BuildContext context, final int i) {
        final SearchResult result = results[i];
        return RecommendationTile(
          result: result,
          onTap: () => onSelect(result),
          animationDelay: Duration(milliseconds: i * 40),
        );
      },
    );
  }
}
