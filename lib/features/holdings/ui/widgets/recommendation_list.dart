import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../logic/services/holding_search_service.dart';
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

  /// Offers "إضافة بيانات جديدة" on the no-results state — `null` when no
  /// city is active (Excel-sourced data has no server to add records to).
  final VoidCallback? onAddNew;

  @override
  Widget build(final BuildContext context) {
    if (query.trim().isEmpty) return const SizedBox.shrink();

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'holdings.search.no_results'.tr(),
                style: AppTextStyles.font14Regular.copyWith(
                  color: context.customColors.textHint,
                ),
              ),
              if (onAddNew != null) ...[
                verticalSpacing(16),
                CustomTextButton(
                  text: 'holdings.add.new_person_cta'.tr(),
                  onPressed: onAddNew,
                  isFullWidth: false,
                  prefixIcon: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: AppColors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
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
