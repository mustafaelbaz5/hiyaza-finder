import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/local/area_calculator.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../../data/model/jazla.dart';

class JazlaAreaSummary extends StatelessWidget {
  const JazlaAreaSummary(
      {super.key, required this.jazla, required this.parcels});

  final Jazla jazla;
  final List<Parcel> parcels;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final double added = parcels.fold<double>(
      0,
      (final double total, final Parcel parcel) =>
          total +
          (AreaCalculator.totalSqm(
                feddan: parcel.feddan,
                qirat: parcel.qirat,
                sahm: parcel.sahm,
              ) ??
              0),
    );
    final int missing = parcels
        .where((final Parcel parcel) =>
            AreaCalculator.totalSqm(
              feddan: parcel.feddan,
              qirat: parcel.qirat,
              sahm: parcel.sahm,
            ) ==
            null)
        .length;
    final double? target = jazla.targetAreaSqm;
    final double difference = target == null ? 0 : target - added;
    final bool exceeded = target != null && difference < 0;
    final bool matched = target != null && difference.abs() < 0.01;
    final String status = target == null
        ? 'jazla.area.no_target'.tr()
        : matched
            ? 'jazla.area.matched'.tr()
            : exceeded
                ? 'jazla.area.exceeded'.tr()
                : 'jazla.area.remaining'.tr();
    final Color statusColor = target == null
        ? colors.textSecondary
        : exceeded
            ? AppColors.red200
            : matched
                ? AppColors.green200
                : AppColors.primary200;

    return Container(
      margin: EdgeInsets.fromLTRB(rw(16), rh(8), rw(16), rh(8)),
      padding: EdgeInsets.all(rw(14)),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(status,
                      style: TextStyle(
                          color: statusColor, fontWeight: FontWeight.w700))),
              Text('${parcels.length} ${'jazla.parcel_count_short'.tr()}',
                  style: TextStyle(color: colors.textSecondary)),
            ],
          ),
          verticalSpacing(10),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _Metric(
                  label: 'jazla.area.added'.tr(),
                  value: _format(added),
                  color: colors.textPrimary),
              if (target != null)
                _Metric(
                    label: 'jazla.area.target'.tr(),
                    value: _format(target),
                    color: colors.textPrimary),
              if (target != null)
                _Metric(
                    label: status,
                    value: _format(difference.abs()),
                    color: statusColor),
              if (missing > 0)
                _Metric(
                    label: 'jazla.area.missing'.tr(),
                    value: missing.toString(),
                    color: AppColors.amber200),
            ],
          ),
        ],
      ),
    );
  }

  String _format(final double value) => value.toStringAsFixed(2);
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(final BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: context.customColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ],
      );
}
