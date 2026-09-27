import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/widgets/custom_text_form_.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../cities/data/model/association_type.dart';

Future<List<String>?> showNotesManagementSheet(
  final BuildContext context, {
  required final List<String> notes,
  final AssociationType? associationType,
  final ValueChanged<List<String>>? onDraftChanged,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (final BuildContext context) => _NotesManagementSheet(
      initialNotes: notes,
      associationType: associationType,
      onDraftChanged: onDraftChanged,
    ),
  );
}

class _NotesManagementSheet extends StatefulWidget {
  const _NotesManagementSheet({
    required this.initialNotes,
    this.associationType,
    this.onDraftChanged,
  });

  final List<String> initialNotes;
  final AssociationType? associationType;
  final ValueChanged<List<String>>? onDraftChanged;

  @override
  State<_NotesManagementSheet> createState() => _NotesManagementSheetState();
}

class _NotesManagementSheetState extends State<_NotesManagementSheet> {
  late List<String> _notes;
  late final TextEditingController _controller;

  List<String> get _suggestions {
    final List<String> values = <String>[
      ...Parcel.notesOptions,
      if (widget.associationType == AssociationType.agriculturalReform)
        ...Parcel.reformTypeOptions,
    ];
    return values.toSet().toList();
  }

  @override
  void initState() {
    super.initState();
    _notes = List<String>.of(widget.initialNotes);
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _emitDraft() => widget.onDraftChanged?.call(List<String>.of(_notes));

  void _setNotes(final List<String> notes) {
    setState(() => _notes = notes);
    _emitDraft();
  }

  void _toggleSuggestion(final String note) {
    final List<String> next = List<String>.of(_notes);
    if (next.contains(note)) {
      next.remove(note);
    } else {
      next.add(note);
    }
    _setNotes(next);
  }

  void _addTypedNote() {
    final String note = _controller.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (note.isEmpty || _notes.contains(note)) {
      _controller.clear();
      return;
    }
    _setNotes(<String>[..._notes, note]);
    _controller.clear();
  }

  List<String> _commitPendingText() {
    final String note = _controller.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (note.isNotEmpty && !_notes.contains(note)) {
      _notes = <String>[..._notes, note];
      _emitDraft();
    }
    _controller.clear();
    return List<String>.of(_notes);
  }

  void _close() => Navigator.pop(context, _commitPendingText());

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: rh(680)),
        padding: EdgeInsets.fromLTRB(
          rw(16),
          rh(12),
          rw(16),
          rh(12) + bottomInset,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(rr(22))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            verticalSpacing(10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'holdings.fields.notes'.tr(),
                    style: AppTextStyles.font18Bold.copyWith(
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                IconButton(
                  tooltip: 'app_dialogs.close'.tr(),
                  onPressed: _close,
                  icon: Icon(Icons.close_rounded, color: colors.iconSecondary),
                ),
              ],
            ),
            verticalSpacing(8),
            CustomTextForm(
              hintText: 'holdings.notes_field.free_text_hint'.tr(),
              controller: _controller,
              isRTL: true,
              textInputAction: TextInputAction.done,
              prefixIcon:
                  Icon(Icons.edit_note_rounded, color: colors.iconSecondary),
              suffixIcon: IconButton(
                tooltip: 'holdings.notes_field.add_button'.tr(),
                onPressed: _addTypedNote,
                icon: const Icon(Icons.add_rounded),
              ),
            ),
            verticalSpacing(14),
            Text(
              'holdings.fields.notes'.tr(),
              style: AppTextStyles.font12Medium.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
            verticalSpacing(6),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (_notes.isEmpty)
                    Text(
                      'holdings.notes_field.empty'.tr(),
                      style: AppTextStyles.font14Regular.copyWith(
                        color: colors.textHint,
                      ),
                      textAlign: TextAlign.center,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final String note in _notes)
                          InputChip(
                            label: Text(note),
                            onDeleted: () => _setNotes(
                              _notes
                                  .where((final String value) => value != note)
                                  .toList(),
                            ),
                            deleteIcon: const Icon(Icons.close_rounded),
                          ),
                      ],
                    ),
                  verticalSpacing(14),
                  Text(
                    'holdings.notes_field.quick_list_title'.tr(),
                    style: AppTextStyles.font12Medium.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  verticalSpacing(6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final String note in _suggestions)
                        FilterChip(
                          label: Text(note),
                          selected: _notes.contains(note),
                          onSelected: (final _) => _toggleSuggestion(note),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            verticalSpacing(12),
            FilledButton.icon(
              onPressed: _close,
              icon: const Icon(Icons.check_rounded),
              label: Text('holdings.add.save'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
