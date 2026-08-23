import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../cities/data/model/association_type.dart';
import 'notes_management_sheet.dart';

/// Collapsed ملاحظات row shown on the Detail Screen card (UI/UX Updates
/// prompt "Change 9", Part A) — first note (truncated), a "(+N)" count for
/// the rest, and a chevron; tapping anywhere on the row opens
/// [showNotesManagementSheet] (Part B) for the full add/remove UI. Replaces
/// the old always-expanded chip list, which took up card space
/// proportional to how many notes a parcel had.
class NotesField extends StatelessWidget {
  const NotesField({
    super.key,
    required this.notes,
    required this.onChanged,
    this.onNoteAdded,
    this.isModified = false,
    this.associationType,
  });

  final List<String> notes;
  final ValueChanged<List<String>> onChanged;

  /// Called with just the newly-added note (in addition to [onChanged]
  /// firing with the full list) — lets a caller run APP_UPDATES_CLAUDE.md
  /// § 4.3's bidirectional نوع الاستخدام↔notes logic, or the Credit/Reform
  /// Type Logic prompt's reform-note↔نوع الإصلاح logic, without needing to
  /// diff two lists to find what changed.
  final ValueChanged<String>? onNoteAdded;

  /// Same meaning as `FieldRow.isModified` — highlights the row when the
  /// note list differs from the parcel's original value.
  final bool isModified;

  /// Adds the reform city's 3 quick-select reform notes to the picker when
  /// this is `AssociationType.agriculturalReform` — `null`/credit shows the
  /// built-in list only (Credit/Reform Type Logic prompt).
  final AssociationType? associationType;

  Future<void> _open(final BuildContext context) async {
    final List<String>? updated = await showNotesManagementSheet(
      context,
      notes: notes,
      associationType: associationType,
      onNoteAdded: onNoteAdded,
    );
    if (updated != null) onChanged(updated);
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String firstNote = notes.isEmpty ? '' : notes.first;
    final int remaining = notes.length - 1;

    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isModified
              ? AppColors.amber300.withValues(alpha: 0.08)
              : colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isModified ? AppColors.amber300 : colors.border,
            width: isModified ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: colors.iconSecondary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'holdings.fields.notes'.tr(),
                    style: AppTextStyles.font12Regular.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notes.isEmpty
                        ? '-'
                        : remaining > 0
                            ? 'holdings.notes_field.collapsed_with_count'.tr(
                                namedArgs: {
                                  'note': firstNote,
                                  'count': remaining.toString(),
                                },
                              )
                            : firstNote,
                    style: AppTextStyles.font14SemiBold.copyWith(
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
