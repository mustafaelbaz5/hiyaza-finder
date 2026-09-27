import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/themes/custom_colors.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../parcel_catalog/data/local/area_calculator.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../../data/model/jazla.dart';

/// Compact, reusable Jazla area metrics. It lives in the actions sheet, not
/// above the detail tabs, to keep the daily parcel flow focused.
class JazlaAreaSummary extends StatelessWidget {
  const JazlaAreaSummary({
    super.key,
    required this.jazla,
    required this.parcels,
  });

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
    final int missing = parcels.where((final Parcel parcel) {
      return AreaCalculator.totalSqm(
            feddan: parcel.feddan,
            qirat: parcel.qirat,
            sahm: parcel.sahm,
          ) ==
          null;
    }).length;
    final double? target = jazla.targetAreaSqm;
    final double? difference = target == null ? null : target - added;
    final _AreaStatus status = _AreaStatus.fromDifference(difference, colors);

    return Container(
      padding: const EdgeInsets.all(14),
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
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(status.icon, color: status.color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status.label.tr(),
                  style: AppTextStyles.font14SemiBold
                      .copyWith(color: status.color),
                  textAlign: TextAlign.right,
                ),
              ),
              _ParcelCount(count: parcels.length),
            ],
          ),
          const SizedBox(height: 12),
          _MetricGrid(
            metrics: [
              _MetricData(
                label: 'jazla.area.target'.tr(),
                value: target == null ? '—' : _format(target),
                color: colors.textPrimary,
              ),
              _MetricData(
                label: 'jazla.area.added'.tr(),
                value: _format(added),
                color: colors.textPrimary,
              ),
              if (difference != null)
                _MetricData(
                  label: status.label.tr(),
                  value: _format(difference.abs()),
                  color: status.color,
                ),
              if (missing > 0)
                _MetricData(
                  label: 'jazla.area.missing'.tr(),
                  value: missing.toString(),
                  color: colors.warning,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _format(final double value) => '${value.toStringAsFixed(2)} م²';
}

class _ParcelCount extends StatelessWidget {
  const _ParcelCount({required this.count});

  final int count;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'jazla.parcel_count'.tr(namedArgs: <String, String>{'count': '$count'}),
        style:
            AppTextStyles.font12Regular.copyWith(color: colors.textSecondary),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(final BuildContext context) {
    return LayoutBuilder(
      builder: (final BuildContext context, final BoxConstraints constraints) {
        final double metricWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: metrics.map((final _MetricData metric) {
            return SizedBox(width: metricWidth, child: _Metric(data: metric));
          }).toList(),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

class _Metric extends StatelessWidget {
  const _Metric({required this.data});

  final _MetricData data;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.font12Regular
                .copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            data.value,
            style: AppTextStyles.font14SemiBold.copyWith(color: data.color),
          ),
        ],
      ),
    );
  }
}

class _AreaStatus {
  const _AreaStatus._(this.label, this.color, this.background, this.icon);

  final String label;
  final Color color;
  final Color background;
  final IconData icon;

  static _AreaStatus fromDifference(
    final double? difference,
    final CustomColors colors,
  ) {
    if (difference == null) {
      return _AreaStatus._(
        'jazla.area.no_target',
        colors.info,
        colors.infoBackground,
        Icons.info_outline_rounded,
      );
    }
    if (difference.abs() < 0.01) {
      return _AreaStatus._(
        'jazla.area.matched',
        colors.success,
        colors.successBackground,
        Icons.check_circle_outline_rounded,
      );
    }
    if (difference < 0) {
      return _AreaStatus._(
        'jazla.area.exceeded',
        colors.error,
        colors.errorBackground,
        Icons.warning_amber_rounded,
      );
    }
    return _AreaStatus._(
      'jazla.area.remaining',
      colors.info,
      colors.infoBackground,
      Icons.straighten_rounded,
    );
  }
}
