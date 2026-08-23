import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_form_.dart';
import '../../data/local/holding_search_service.dart';
import '../../data/model/parcel.dart';
import '../../data/repo/holdings_repository.dart';

/// رقم الحيازة exact-match search for "حيازة جديدة لشخص موجود"
/// (APP_UPDATES_CLAUDE.md § 2.2) — on a match, shows the found person's
/// اسم الحائز/رقم الحيازة for confirmation and lets the caller continue
/// into the pre-filled add-parcel form via [onConfirm].
class ExistingPersonSearch extends StatefulWidget {
  const ExistingPersonSearch({super.key, required this.onConfirm});

  /// Called with the matched holding's parcels once the user confirms.
  final ValueChanged<List<Parcel>> onConfirm;

  @override
  State<ExistingPersonSearch> createState() => _ExistingPersonSearchState();
}

class _ExistingPersonSearchState extends State<ExistingPersonSearch> {
  final TextEditingController _controller = TextEditingController();
  final HoldingsRepository _repository = getIt<HoldingsRepository>();
  static const HoldingSearchService _searchService = HoldingSearchService();

  List<Parcel>? _matchedParcels;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(final String query) {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _matchedParcels = null;
        _searched = false;
      });
      return;
    }

    final List<ScoredParcel> matches =
        _searchService.searchByHoldingNumber(_repository.parcels, trimmed);
    setState(() {
      _searched = true;
      _matchedParcels = matches.isEmpty
          ? null
          : _repository.parcelsForHolding(matches.first.parcel.holdingId);
    });
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final List<Parcel>? matched = _matchedParcels;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rw(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          verticalSpacing(16),
          CustomTextForm(
            hintText: 'holdings.add.search_holding_id_hint'.tr(),
            controller: _controller,
            isRTL: true,
            keyboardType: TextInputType.number,
            prefixIcon: Icon(Icons.search_rounded, color: colors.iconSecondary),
            onChanged: _search,
          ),
          verticalSpacing(16),
          if (_searched && matched == null)
            Text(
              'holdings.add.search_no_match'.tr(),
              style: AppTextStyles.font14Regular.copyWith(color: colors.textHint),
              textAlign: TextAlign.center,
            )
          else if (matched != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    matched.first.holderName ?? '-',
                    style: AppTextStyles.font16SemiBold.copyWith(
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  verticalSpacing(4),
                  Text(
                    'holdings.detail.title'.tr(
                      namedArgs: {'id': matched.first.holdingId},
                    ),
                    style: AppTextStyles.font12Regular.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            verticalSpacing(16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary200,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => widget.onConfirm(matched),
                child: Text(
                  'holdings.add.confirm_person'.tr(),
                  style: AppTextStyles.font14Bold.copyWith(color: AppColors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
