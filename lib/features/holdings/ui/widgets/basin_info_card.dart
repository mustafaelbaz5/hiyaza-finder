import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../cities/data/model/basin.dart';

/// كود الحوض/إجمالي القطع/المساحة الكلية for one basin — the info block at
/// the top of [BasinScreen] (APP_CLAUDE.md § 9.3). `null` when the active
/// city has no matching server-side [Basin] row (e.g. an old cached
/// snapshot downloaded before basins existed) — the card just omits the
/// values it can't show, rather than displaying zeros.
class BasinInfoCard extends StatelessWidget {
  const BasinInfoCard({super.key, this.basin});

  final Basin? basin;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final Basin? b = basin;
    if (b == null) return const SizedBox.shrink();

    final double totalSqm = b.totalSqm;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: rw(16)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            label: 'holdings.basin.code_title'.tr(),
            value: b.basinCode ?? '-',
          ),
          verticalSpacing(6),
          _InfoRow(
            label: 'holdings.basin.total_parcels'.tr(),
            value: b.parcelCount.toString(),
          ),
          verticalSpacing(6),
          _InfoRow(
            label: 'holdings.basin.total_area'.tr(),
            value: 'holdings.basin.total_area_value'.tr(
              namedArgs: {'value': totalSqm.toStringAsFixed(0)},
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Row(
      children: [
        Text(
          value,
          style: AppTextStyles.font14Bold.copyWith(color: colors.textPrimary),
        ),
        const Spacer(),
        Text(
          label,
          style: AppTextStyles.font14Regular.copyWith(color: colors.textSecondary),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }
}
