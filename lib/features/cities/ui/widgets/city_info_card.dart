import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../holdings/data/repo/holdings_repository.dart';
import '../../data/model/association_type.dart';

/// The active city's identity block at the top of `CityToolsScreen`
/// (APP_CLAUDE.md § 10.2) — اسم/كود الجمعية (each copyable), المديرية،
/// الإدارة. `null`/empty fields are simply omitted rather than shown as
/// blank rows.
class CityInfoCard extends StatelessWidget {
  const CityInfoCard({super.key});

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final HoldingsRepository repository = getIt<HoldingsRepository>();

    final String? cityName = repository.activeCityName;
    final String? associationName = repository.defaultAssociationName;
    final String? associationCode = repository.defaultAssociationCode;
    final String? directorate = repository.activeDirectorate;
    final String? administration = repository.activeAdministration;
    final AssociationType? type = repository.activeAssociationType;

    if (cityName == null) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: rw(16)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            cityName,
            style: AppTextStyles.font18Bold.copyWith(color: colors.textPrimary),
            textAlign: TextAlign.right,
          ),
          if (type != null) ...[
            verticalSpacing(2),
            Text(
              type == AssociationType.agriculturalReform
                  ? 'holdings.association_type.agricultural_reform'.tr()
                  : 'holdings.association_type.agricultural_credit'.tr(),
              style: AppTextStyles.font12Regular.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.right,
            ),
          ],
          if (associationName != null) ...[
            verticalSpacing(10),
            Divider(color: colors.border, height: 1),
            verticalSpacing(10),
            _CopyableRow(
              label: 'cities.tools.city_info.association_name'.tr(),
              value: associationName,
            ),
          ],
          if (associationCode != null) ...[
            verticalSpacing(10),
            Divider(color: colors.border, height: 1),
            verticalSpacing(10),
            _CopyableRow(
              label: 'cities.tools.city_info.association_code'.tr(),
              value: associationCode,
            ),
          ],
          if (directorate != null || administration != null) ...[
            verticalSpacing(10),
            Divider(color: colors.border, height: 1),
            verticalSpacing(10),
            Row(
              children: [
                if (directorate != null)
                  Expanded(
                    child: _PlainRow(
                      label: 'holdings.fields.directorate'.tr(),
                      value: directorate,
                    ),
                  ),
                if (administration != null)
                  Expanded(
                    child: _PlainRow(
                      label: 'holdings.fields.administration'.tr(),
                      value: administration,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CopyableRow extends StatelessWidget {
  const _CopyableRow({required this.label, required this.value});

  final String label;
  final String value;

  Future<void> _copy(final BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      HapticFeedback.mediumImpact();
      context.showSuccessSnackBar('holdings.detail.copied'.tr());
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.font12Regular.copyWith(color: colors.textSecondary),
          textAlign: TextAlign.right,
        ),
        verticalSpacing(4),
        Row(
          children: [
            InkWell(
              onTap: () => _copy(context),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: AppColors.primary200,
                ),
              ),
            ),
            horizontalSpacing(4),
            Expanded(
              child: Text(
                value,
                style: AppTextStyles.font14SemiBold.copyWith(color: colors.textPrimary),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlainRow extends StatelessWidget {
  const _PlainRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.font12Regular.copyWith(color: colors.textSecondary),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.font14SemiBold.copyWith(color: colors.textPrimary),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }
}
