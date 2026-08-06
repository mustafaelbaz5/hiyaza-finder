import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/ui/dialogs/choice_dialog.dart';
import '../../../../core/widgets/ui/dialogs/text_input_dialog.dart';
import '../../domain/entities/parcel.dart';

/// The نوع الزرع option that unlocks the free-text follow-up.
const String cropTypeOtherOption = 'اخرى';

/// Shows the نوع الزرع choice dialog; if the user picks "اخرى", immediately
/// follows up with an optional free-text dialog so they can specify the
/// actual crop instead of leaving the value as the literal "اخرى". Shared
/// by the per-parcel detail card and the bulk-edit (file status) screen so
/// both offer the same "specify other" behavior.
///
/// Returns `null` if dismissed without any choice (no change), otherwise a
/// [ChoiceDialogResult] — `isClear` for "—", or a value that's either one
/// of [Parcel.cropTypeOptions] or the custom text typed for "اخرى".
Future<ChoiceDialogResult<String>?> pickCropType(
  final BuildContext context, {
  required final String? selected,
}) async {
  final ChoiceDialogResult<String>? result = await showChoiceDialog<String>(
    context,
    title: 'holdings.fields.crop_type'.tr(),
    options: [
      for (final String option in Parcel.cropTypeOptions)
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
