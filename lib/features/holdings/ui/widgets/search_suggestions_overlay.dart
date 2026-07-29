import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';

/// Live, unscored "narrows as you type" list of matching holder names shown
/// under the search field — tapping one fills the search box so the full
/// (fuzzy-scored, debounced) results below can take over. Complements
/// `RecommendationList`, which stays the source of truth for actual
/// holding-level results (a name alone doesn't identify a holding, since
/// several holdings can share one holder name).
class SearchSuggestionsOverlay extends StatelessWidget {
  const SearchSuggestionsOverlay({
    super.key,
    required this.suggestions,
    required this.onSelect,
  });

  final List<String> suggestions;
  final void Function(String name) onSelect;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: colors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: suggestions.length,
          separatorBuilder: (final BuildContext context, final int index) =>
              Divider(height: 1, color: colors.border),
          itemBuilder: (final BuildContext context, final int i) {
            final String name = suggestions[i];
            return InkWell(
              onTap: () => onSelect(name),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_search_rounded,
                      size: 18,
                      color: AppColors.primary200,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: AppTextStyles.font14SemiBold.copyWith(
                          color: colors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
