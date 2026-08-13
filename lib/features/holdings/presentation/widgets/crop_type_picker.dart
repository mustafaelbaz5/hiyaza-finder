import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/widgets/ui/dialogs/choice_dialog.dart';
import '../../../../core/widgets/ui/dialogs/text_input_dialog.dart';
import '../../../cities/domain/repositories/crop_type_repository.dart';
import '../../data/repository/holdings_repository.dart';
import '../../domain/entities/parcel.dart';

/// The نوع الزرع option that unlocks the free-text follow-up.
const String cropTypeOtherOption = 'اخرى';

/// Shows the نوع الزرع choice dialog; if the user picks "اخرى", immediately
/// follows up with an optional free-text dialog so they can specify the
/// actual crop instead of leaving the value as the literal "اخرى". Shared
/// by the per-parcel detail card and the bulk-edit (file status) screen so
/// both offer the same "specify other" behavior.
///
/// When [options] isn't given explicitly, this fetches the active city's
/// `city_crop_types` list (`CropTypeRepository`, managed from "أدوات
/// المدينة" -> "أنواع الزرع") and offers those instead of the fixed
/// [Parcel.cropTypeOptions] — falling back to the static list if there's no
/// active city, the fetch fails, or the city has no custom types yet, so a
/// city that hasn't set up its own list still works exactly as before.
///
/// Returns `null` if dismissed without any choice (no change), otherwise a
/// [ChoiceDialogResult] — `isClear` for "—", or a value that's either one
/// of the offered options or the custom text typed for "اخرى".
Future<ChoiceDialogResult<String>?> pickCropType(
  final BuildContext context, {
  required final String? selected,
  final List<String>? options,
}) async {
  final List<String> resolvedOptions =
      options ?? await _resolveCropTypeOptions();
  if (!context.mounted) return null;
  final ChoiceDialogResult<String>? result = await showChoiceDialog<String>(
    context,
    title: 'holdings.fields.crop_type'.tr(),
    options: [
      for (final String option in resolvedOptions)
        ChoiceOption<String>(value: option, label: option),
    ],
    selected: selected,
    clearLabel: '—',
  );
  if (result == null || result.isClear) return result;
  if (result.value != cropTypeOtherOption) return result;
  if (!context.mounted) return result;

  final String? custom = await showTextInputDialog(
    context,
    title: 'holdings.crop_type.specify_title'.tr(),
    initialValue: '',
  );
  final String? trimmed = custom?.trim();
  if (trimmed == null || trimmed.isEmpty) return result; // keep "اخرى"
  return ChoiceDialogResult<String>.value(trimmed);
}

Future<List<String>> _resolveCropTypeOptions() async {
  final String? cityId = getIt<HoldingsRepository>().activeCityId;
  if (cityId == null) return Parcel.cropTypeOptions;
  try {
    final List<String> cityCropTypes =
        await getIt<CropTypeRepository>().fetchCropTypes(cityId);
    return cityCropTypes.isEmpty ? Parcel.cropTypeOptions : cityCropTypes;
  } catch (_) {
    return Parcel.cropTypeOptions;
  }
}
