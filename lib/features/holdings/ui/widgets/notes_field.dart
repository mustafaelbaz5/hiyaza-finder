import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../data/model/parcel.dart';
import 'add_note_dialog.dart';

/// ملاحظات as a list of chips — one per note, each independently
/// deletable, plus an "add" affordance opening [showAddNoteDialog] (free
/// text or a pick from [Parcel.notesOptions]). Unlike [FieldRow]'s
/// single-line-truncated display, a parcel can now carry several distinct
/// notes at once, so each needs its own visible slot rather than being
/// joined into one string until edited.
class NotesField extends StatelessWidget {
  const NotesField({
    super.key,
    required this.notes,
    required this.onChanged,
    this.onNoteAdded,
    this.isModified = false,
  });

  final List<String> notes;
  final ValueChanged<List<String>> onChanged;

  /// Called with just the newly-added note (in addition to [onChanged]
  /// firing with the full list) — lets a caller run APP_UPDATES_CLAUDE.md
  /// § 4.3's bidirectional نوع الاستخدام↔notes logic without needing to
  /// diff two lists to find what changed.
  final ValueChanged<String>? onNoteAdded;

  /// Same meaning as `FieldRow.isModified` — highlights the section when
  /// the note list differs from the parcel's original value.
  final bool isModified;

  Future<void> _add(final BuildContext context) async {
    final String? note = await showAddNoteDialog(context);
    if (note == null || note.trim().isEmpty) return;
    if (notes.contains(note)) return;
    if (onNoteAdded != null) {
      onNoteAdded!(note);
    } else {
      onChanged(<String>[...notes, note]);
    }
  }

  void _remove(final String note) {
    onChanged(notes.where((final String n) => n != note).toList());
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'holdings.fields.notes'.tr(),
                  style: AppTextStyles.font12Regular.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              InkWell(
                onTap: () => _add(context),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.add_circle_outline_rounded,
                    size: 20,
                    color: AppColors.primary200,
                  ),
                ),
              ),
            ],
          ),
          if (notes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '-',
                style: AppTextStyles.font14SemiBold.copyWith(
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.right,
              ),
            )
          else ...[
            verticalSpacing(4),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final String note in notes)
                  _NoteChip(note: note, onDelete: () => _remove(note)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteChip extends StatelessWidget {
  const _NoteChip({required this.note, required this.onDelete});

  final String note;
  final VoidCallback onDelete;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Container(
      padding: const EdgeInsets.only(right: 10, left: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              note,
              style: AppTextStyles.font12Regular.copyWith(
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          horizontalSpacing(4),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(10),
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: colors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
