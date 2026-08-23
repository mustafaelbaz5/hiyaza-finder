import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../cities/data/model/association_type.dart';
import 'add_note_dialog.dart';

/// Full ملاحظات management UI (UI/UX Updates prompt "Change 9", Part B) —
/// header with an "+ إضافة" action, a scrollable list of every note with
/// its own delete button, and an empty-state message. Returns the final
/// note list on close (even if unchanged), or `null` if the sheet was
/// dismissed without ever being interacted with meaningfully — in practice
/// this always resolves to a `List<String>` since [Navigator.pop] is only
/// called with one.
///
/// Fixes the BoxConstraints-forces-infinite-width crash this used to throw
/// (UI/UX Updates prompt "Change 6"): the old dialog nested a `Row` (from
/// `_NoteChip`) inside a `Wrap` inside an unconstrained `Column` reached
/// through a modal route with no width bound in one call path. Every row
/// here is now built inside a `ListView`/`Column` whose parent
/// (`showModalBottomSheet`'s route) already constrains width to the
/// screen, and each row's text is wrapped in `Expanded` so it can never
/// ask its parent for unbounded width.
Future<List<String>?> showNotesManagementSheet(
  final BuildContext context, {
  required final List<String> notes,
  final AssociationType? associationType,
  final ValueChanged<String>? onNoteAdded,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (final BuildContext context) => _NotesManagementSheet(
      initialNotes: notes,
      associationType: associationType,
      onNoteAdded: onNoteAdded,
    ),
  );
}

class _NotesManagementSheet extends StatefulWidget {
  const _NotesManagementSheet({
    required this.initialNotes,
    this.associationType,
    this.onNoteAdded,
  });

  final List<String> initialNotes;
  final AssociationType? associationType;
  final ValueChanged<String>? onNoteAdded;

  @override
  State<_NotesManagementSheet> createState() => _NotesManagementSheetState();
}

class _NotesManagementSheetState extends State<_NotesManagementSheet> {
  late List<String> _notes;

  @override
  void initState() {
    super.initState();
    _notes = List<String>.of(widget.initialNotes);
  }

  Future<void> _add() async {
    final String? note = await showAddNoteDialog(
      context,
      associationType: widget.associationType,
    );
    if (note == null || note.trim().isEmpty) return;
    if (_notes.contains(note)) return;
    setState(() => _notes = <String>[..._notes, note]);
    // The caller's bidirectional sync (نوع الاستخدام/نوع الإصلاح ↔ notes)
    // still needs to run against the *pre-add* parcel — reported alongside
    // the local list update rather than folded into it, same contract the
    // old inline `NotesField._add` used.
    widget.onNoteAdded?.call(note);
  }

  void _remove(final String note) {
    setState(() => _notes = _notes.where((final String n) => n != note).toList());
  }

  void _close() => Navigator.pop(context, _notes);

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: rh(560)),
        padding: EdgeInsets.fromLTRB(rw(20), rh(16), rw(20), rh(20)),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(rr(20))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            verticalSpacing(16),
            Row(
              children: [
                InkWell(
                  onTap: _add,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 18,
                          color: AppColors.primary200,
                        ),
                        horizontalSpacing(4),
                        Text(
                          'holdings.notes_field.add_button'.tr(),
                          style: AppTextStyles.font14SemiBold.copyWith(
                            color: AppColors.primary200,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'holdings.fields.notes'.tr(),
                    style: AppTextStyles.font18Bold.copyWith(
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            verticalSpacing(12),
            Divider(color: colors.border, height: 1),
            Flexible(
              child: _notes.isEmpty
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: rh(32)),
                      child: Text(
                        'holdings.notes_field.empty'.tr(),
                        style: AppTextStyles.font14Regular.copyWith(
                          color: colors.textHint,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.symmetric(vertical: rh(8)),
                      itemCount: _notes.length,
                      separatorBuilder: (final _, final __) =>
                          Divider(color: colors.border, height: 1),
                      itemBuilder: (final BuildContext context, final int i) {
                        final String note = _notes[i];
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: rh(10)),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => _remove(note),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: colors.textHint,
                                  ),
                                ),
                              ),
                              horizontalSpacing(8),
                              Expanded(
                                child: Text(
                                  note,
                                  style: AppTextStyles.font14Regular.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            verticalSpacing(12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary200,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _close,
                child: Text(
                  'app_dialogs.close'.tr(),
                  style: AppTextStyles.font14Bold.copyWith(
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
