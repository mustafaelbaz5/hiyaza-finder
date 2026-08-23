import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../../core/widgets/custom_text_form_.dart';
import '../../data/local/notes_list_service.dart';

/// City Tools' ملاحظات settings (APP_UPDATES_CLAUDE.md § 5.4) — lets the
/// field worker add/remove notes from the app-wide quick-pick list
/// ([NotesListService]'s custom layer). Doesn't touch notes already saved
/// on any parcel.
Future<void> showNotesSettingsSheet(final BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (final BuildContext context) => const _NotesSettingsSheet(),
  );
}

class _NotesSettingsSheet extends StatefulWidget {
  const _NotesSettingsSheet();

  @override
  State<_NotesSettingsSheet> createState() => _NotesSettingsSheetState();
}

class _NotesSettingsSheetState extends State<_NotesSettingsSheet> {
  final NotesListService _service = getIt<NotesListService>();
  final TextEditingController _controller = TextEditingController();
  List<String> _customNotes = const <String>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final List<String> notes = await _service.getCustomNotes();
    if (mounted) setState(() => _customNotes = notes);
  }

  Future<void> _add() async {
    final String value = _controller.text.trim();
    if (value.isEmpty) return;
    await _service.addNote(value);
    _controller.clear();
    await _load();
  }

  Future<void> _remove(final String note) async {
    await _service.removeNote(note);
    await _load();
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return SafeArea(
      child: Container(
        padding: EdgeInsets.all(rw(20)),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(rr(20))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'cities.tools.notes_settings.title'.tr(),
              style: AppTextStyles.font18Bold.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
            verticalSpacing(16),
            Row(
              children: [
                Expanded(
                  child: CustomTextForm(
                    hintText: 'holdings.notes_field.free_text_hint'.tr(),
                    controller: _controller,
                    isRTL: true,
                  ),
                ),
                horizontalSpacing(8),
                CustomTextButton(
                  text: 'cities.tools.notes_settings.add'.tr(),
                  size: CustomButtonSize.small,
                  onPressed: _add,
                ),
              ],
            ),
            verticalSpacing(16),
            if (_customNotes.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: rh(12)),
                child: Text(
                  'cities.tools.notes_settings.empty'.tr(),
                  style: AppTextStyles.font14Regular.copyWith(
                    color: colors.textHint,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: rh(260)),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _customNotes.length,
                  separatorBuilder: (final _, final __) => verticalSpacing(4),
                  itemBuilder: (final BuildContext context, final int index) {
                    final String note = _customNotes[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        note,
                        style: AppTextStyles.font14Regular.copyWith(
                          color: colors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline_rounded,
                            color: AppColors.red300),
                        onPressed: () => _remove(note),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
