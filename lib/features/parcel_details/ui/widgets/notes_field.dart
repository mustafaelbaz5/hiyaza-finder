import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../cities/data/model/association_type.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../../../parcel_editor/data/local/parcel_notes_sync.dart';
import '../../../cities/ui/widgets/notes_management_sheet.dart';

class NotesField extends StatelessWidget {
  const NotesField({
    super.key,
    required this.parcel,
    required this.onParcelChanged,
    this.isModified = false,
    this.associationType,
  });

  final Parcel parcel;
  final ValueChanged<Parcel> onParcelChanged;
  final bool isModified;
  final AssociationType? associationType;

  Future<void> _open(final BuildContext context) async {
    final List<String>? updated = await showNotesManagementSheet(
      context,
      notes: parcel.notes,
      associationType: associationType,
      onDraftChanged: (final List<String> notes) {
        onParcelChanged(ParcelNotesSync.applyChangedNotes(parcel, notes));
      },
    );
    if (updated != null) {
      onParcelChanged(ParcelNotesSync.applyChangedNotes(parcel, updated));
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String firstNote = parcel.notes.isEmpty ? '' : parcel.notes.first;
    final int remaining = parcel.notes.length - 1;

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
              Icons.notes_rounded,
              size: 20,
              color: colors.iconSecondary,
            ),
            const SizedBox(width: 8),
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
                    parcel.notes.isEmpty
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
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: colors.iconSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
