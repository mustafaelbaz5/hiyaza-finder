import 'package:flutter/material.dart';

import '../../../../core/widgets/ui/dialogs/choice_dialog.dart';
import '../../../../core/widgets/ui/dialogs/text_input_dialog.dart';

/// Shows a choice dialog over [options]; if the user picks [otherOption],
/// immediately follows up with a free-text dialog titled [specifyTitle] so
/// they can enter a value that doesn't fit any of the fixed options instead
/// of leaving the value as the literal [otherOption] string. Generalizes the
/// نوع الزرع "specify other" flow (`pickCropType`) so any fixed-option field
/// — ملاحظات included (`REFACTOR_ROADMAP.md` Phase 12) — can offer the same
/// escape hatch without duplicating the follow-up-dialog logic.
///
/// Returns `null` if dismissed without any choice (no change), otherwise a
/// [ChoiceDialogResult] — `isClear` for "—", or a value that's either one of
/// [options] or the custom text typed for [otherOption].
Future<ChoiceDialogResult<String>?> pickWithOther(
  final BuildContext context, {
  required final String title,
  required final String? selected,
  required final List<String> options,
  required final String otherOption,
  required final String specifyTitle,
  final String? clearLabel,
}) async {
  final ChoiceDialogResult<String>? result = await showChoiceDialog<String>(
    context,
    title: title,
    options: [
      for (final String option in options)
        ChoiceOption<String>(value: option, label: option),
    ],
    selected: selected,
    clearLabel: clearLabel,
  );
  if (result == null || result.isClear) return result;
  if (result.value != otherOption) return result;
  if (!context.mounted) return result;

  final String? custom = await showTextInputDialog(
    context,
    title: specifyTitle,
    initialValue: '',
  );
  final String? trimmed = custom?.trim();
  if (trimmed == null || trimmed.isEmpty) return result; // keep otherOption
  return ChoiceDialogResult<String>.value(trimmed);
}
