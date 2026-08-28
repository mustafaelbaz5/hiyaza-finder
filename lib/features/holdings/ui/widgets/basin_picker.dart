import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/widgets/ui/dialogs/choice_dialog.dart';
import '../../data/model/parcel.dart';
import '../../data/repo/holdings_repository.dart';

/// The result of picking اسم الحوض — carries the matching كود الحوض
/// alongside it, since a chosen basin always sets both together
/// (APP_UPDATES_CLAUDE.md § 2.3: "لا يوجد تدخل من اليوزر في كود الحوض").
class BasinPickResult {
  const BasinPickResult({required this.basinName, required this.basinCode});

  final String? basinName;
  final String? basinCode;
}

/// Shows a choice dialog over the active city's أحواض (from
/// `CitySnapshot.basins`, downloaded alongside the city). Choosing one
/// resolves its `basin_code` from `HoldingsRepository.basinByName`
/// automatically — the user never enters a basin code directly. Falls back
/// to a free-text prompt if the active city has no basin list at all (an
/// old cached snapshot downloaded before basins existed).
Future<BasinPickResult?> pickBasin(
  final BuildContext context, {
  required final String? selected,
}) async {
  final HoldingsRepository repository = getIt<HoldingsRepository>();
  final List<String> basins = repository.availableBasins;

  if (basins.isEmpty) return null;

  final ChoiceDialogResult<String>? result = await showChoiceDialog<String>(
    context,
    title: 'holdings.fields.basin_name'.tr(),
    options: [
      for (final String basin in basins)
        ChoiceOption<String>(value: basin, label: basin),
    ],
    selected: selected,
    clearLabel: '—',
  );
  if (result == null) return null;
  if (result.isClear) return const BasinPickResult(basinName: null, basinCode: null);

  final String basinName = result.value!;
  return BasinPickResult(
    basinName: basinName,
    basinCode: repository.basinByName(basinName)?.basinCode,
  );
}

/// Applies a [BasinPickResult] onto [parcel] — sets اسم الحوض and كود الحوض
/// together, per § 2.3.
Parcel applyBasinPick(final Parcel parcel, final BasinPickResult pick) =>
    parcel.copyWith(basinName: pick.basinName, basinCode: pick.basinCode);
