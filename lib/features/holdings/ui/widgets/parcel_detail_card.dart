import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../../core/widgets/ui/dialogs/choice_dialog.dart';
import '../../../../core/widgets/ui/dialogs/text_input_dialog.dart';
import '../../data/models/parcel.dart';
import '../../logic/services/area_calculator.dart';
import 'border_compass.dart';
import 'field_edit_dialogs.dart';
import 'field_row.dart';

/// One parcel's full record: border compass + field tiles + copy-all.
/// Detail screens stack one of these per parcel belonging to a holding.
/// Fields are laid out in a responsive wrap (1 column on phones, more on
/// tablets/laptops) so the card stays compact instead of one long list.
class ParcelDetailCard extends StatelessWidget {
  const ParcelDetailCard({
    super.key,
    required this.parcel,
    required this.onFieldChanged,
    this.isEdited = false,
    this.animationDelay = Duration.zero,
  });

  final Parcel parcel;

  /// Called with a fully-updated [Parcel] whenever a single field is saved
  /// via its inline pencil-icon editor — the only way fields are edited.
  final void Function(Parcel updated) onFieldChanged;
  final bool isEdited;
  final Duration animationDelay;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Container(
      padding: EdgeInsets.all(rw(12)),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isEdited) ...<Widget>[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.amber200.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.edit_note_rounded,
                      size: 14,
                      color: AppColors.amber300,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'holdings.edit.edited_badge'.tr(),
                      style: AppTextStyles.font12Bold.copyWith(
                        color: AppColors.amber300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            verticalSpacing(8),
          ],
          BorderCompass(
            holdingId: parcel.holdingId,
            north: parcel.borderNorth,
            south: parcel.borderSouth,
            east: parcel.borderEast,
            west: parcel.borderWest,
          ),
          verticalSpacing(10),
          CustomTextButton.outlined(
            text: 'holdings.detail.copy_all'.tr(),
            size: CustomButtonSize.small,
            isFullWidth: false,
            prefixIcon: const Icon(
              Icons.copy_all_rounded,
              color: AppColors.primary200,
            ),
            onPressed: () => _copyAll(context),
          ),
          verticalSpacing(8),
          _ResponsiveFieldsWrap(
            children: [
              FieldRow(
                label: 'holdings.detail.holding_id'.tr(),
                value: parcel.holdingId,
              ),
              FieldRow(
                label: 'اسم المالك',
                value: parcel.ownerName,
                onEdit: () => _editText(
                  context,
                  title: 'اسم المالك',
                  initialValue: parcel.ownerName ?? '',
                  apply: (final String v) =>
                      parcel.copyWith(ownerName: v.isEmpty ? null : v),
                ),
              ),
              FieldRow(
                label: 'اسم الحائز',
                value: parcel.holderName,
                onEdit: () => _editText(
                  context,
                  title: 'اسم الحائز',
                  initialValue: parcel.holderName ?? '',
                  apply: (final String v) =>
                      parcel.copyWith(holderName: v.isEmpty ? null : v),
                ),
              ),
              FieldRow(
                label: 'الرقم القومي',
                value: parcel.nationalId,
                onEdit: () => _editText(
                  context,
                  title: 'الرقم القومي',
                  initialValue: parcel.nationalId ?? '',
                  keyboardType: TextInputType.number,
                  apply: (final String v) =>
                      parcel.copyWith(nationalId: v.isEmpty ? null : v),
                ),
              ),
              FieldRow(label: 'اسم الجمعية', value: parcel.associationName),
              FieldRow(
                label: 'اسم الحوض',
                value: parcel.basinName,
                onEdit: () => _editText(
                  context,
                  title: 'اسم الحوض',
                  initialValue: parcel.basinName ?? '',
                  apply: (final String v) =>
                      parcel.copyWith(basinName: v.isEmpty ? null : v),
                ),
              ),
              FieldRow(
                label: 'رقم الأرض',
                value: parcel.landNumber,
                onEdit: () => _editText(
                  context,
                  title: 'رقم الأرض',
                  initialValue: parcel.landNumber ?? '',
                  apply: (final String v) =>
                      parcel.copyWith(landNumber: v.isEmpty ? null : v),
                ),
              ),
              FieldRow(
                label: 'المساحة',
                value: _areaFraction(parcel),
                onEdit: () => _editArea(context),
              ),
              FieldRow(
                label: 'المساحة بالمتر',
                value: _formatNumber(parcel.totalSqm),
              ),
              FieldRow(
                label: 'نوع الزرع',
                value: parcel.cropType,
                onEdit: () => _editDropdown(
                  context,
                  title: 'نوع الزرع',
                  initialValue: parcel.cropType,
                  options: Parcel.cropTypeOptions,
                  apply: (final String? v) => parcel.copyWith(cropType: v),
                ),
              ),
              FieldRow(
                label: 'ملاحظات',
                value: parcel.notes,
                onEdit: () => _editDropdown(
                  context,
                  title: 'ملاحظات',
                  initialValue: parcel.notes,
                  options: Parcel.notesOptions,
                  apply: (final String? v) => parcel.copyWith(notes: v),
                ),
              ),
              FieldRow(
                label: 'نوع الائتمان',
                value: parcel.creditType,
                onEdit: () => _editDropdown(
                  context,
                  title: 'نوع الائتمان',
                  initialValue: parcel.creditType,
                  options: Parcel.creditTypeOptions,
                  allowClear: false,
                  apply: (final String? v) =>
                      parcel.copyWith(creditType: v ?? Parcel.defaultCreditType),
                ),
              ),
              FieldRow(
                label: 'وراثة',
                value: parcel.isInheritance ? 'وراثة' : 'ليست وراثة',
                onEdit: () => _editSwitch(context),
              ),
            ],
          ),
          verticalSpacing(6),
          _SeeMoreSection(parcel: parcel, onFieldChanged: onFieldChanged),
        ],
      ),
    )
        .animate(delay: animationDelay)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Future<void> _editText(
    final BuildContext context, {
    required final String title,
    required final String initialValue,
    required final Parcel Function(String value) apply,
    final TextInputType? keyboardType,
  }) async {
    final String? value = await showTextInputDialog(
      context,
      title: title,
      initialValue: initialValue,
      keyboardType: keyboardType,
    );
    if (value == null) return;
    onFieldChanged(apply(value));
  }

  Future<void> _editDropdown(
    final BuildContext context, {
    required final String title,
    required final String? initialValue,
    required final List<String> options,
    required final Parcel Function(String? value) apply,
    final bool allowClear = true,
  }) async {
    final ChoiceDialogResult<String>? result = await showChoiceDialog<String>(
      context,
      title: title,
      options: [
        for (final String option in options)
          ChoiceOption<String>(value: option, label: option),
      ],
      selected: initialValue,
      clearLabel: allowClear ? '—' : null,
    );
    if (result == null) return;
    onFieldChanged(apply(result.isClear ? null : result.value));
  }

  Future<void> _editSwitch(final BuildContext context) async {
    final ChoiceDialogResult<bool>? result = await showChoiceDialog<bool>(
      context,
      title: 'وراثة',
      options: const [
        ChoiceOption<bool>(value: true, label: 'وراثة'),
        ChoiceOption<bool>(value: false, label: 'ليست وراثة'),
      ],
      selected: parcel.isInheritance,
    );
    if (result == null || result.isClear) return;
    onFieldChanged(parcel.copyWith(isInheritance: result.value!));
  }

  Future<void> _editArea(final BuildContext context) async {
    final AreaEditResult? result = await showAreaFieldEditDialog(
      context,
      feddan: parcel.feddan,
      qirat: parcel.qirat,
      sahm: parcel.sahm,
    );
    if (result == null) return;
    onFieldChanged(
      parcel.copyWith(
        feddan: result.feddan,
        qirat: result.qirat,
        sahm: result.sahm,
        totalSqm: AreaCalculator.totalSqm(
          feddan: result.feddan,
          qirat: result.qirat,
          sahm: result.sahm,
        ),
      ),
    );
  }

  /// `null`/empty values are formatted with [FieldRow.emptyPlaceholder] so
  /// the on-screen display and the copy-all text stay consistent.
  String? _formatNumber(final double? value) {
    if (value == null) return null;
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  String _areaFraction(final Parcel p) {
    final String feddan = _formatNumber(p.feddan) ?? FieldRow.emptyPlaceholder;
    final String qirat = _formatNumber(p.qirat) ?? FieldRow.emptyPlaceholder;
    final String sahm = _formatNumber(p.sahm) ?? FieldRow.emptyPlaceholder;
    return '$feddan فدان، $qirat قيراط، $sahm سهم';
  }

  Future<void> _copyAll(final BuildContext context) async {
    final String text = _formatForClipboard(parcel);
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      HapticFeedback.mediumImpact();
      context.showSuccessSnackBar('holdings.detail.copied'.tr());
    }
  }

  /// One "label: value," field per line (blank slots kept, never skipped)
  /// so the pasted text both reads clearly on its own and lines up
  /// row-for-row when pasted into an external spreadsheet template.
  String _formatForClipboard(final Parcel p) {
    String slot(final String? v) =>
        (v == null || v.trim().isEmpty) ? FieldRow.emptyPlaceholder : v.trim();

    final String holderName = p.holderName?.trim() ?? '';
    final String holderSlot = p.isInheritance
        ? '(ورثة) ${holderName.isEmpty ? FieldRow.emptyPlaceholder : holderName}'
        : slot(p.holderName);
    final String nationalIdSlot = (p.nationalId == null || p.nationalId!.trim().isEmpty)
        ? '11111111111111'
        : p.nationalId!.trim();
    final String creditSentence = p.creditType == 'أوقاف'
        ? 'هذه الأرض تابعة لهيئة الأوقاف المصرية'
        : '';

    final List<(String, String)> fields = <(String, String)>[
      ('رقم الحيازة', p.holdingId),
      ('اسم المالك', slot(p.ownerName)),
      ('اسم الحائز', holderSlot),
      ('الرقم القومي', nationalIdSlot),
      ('اسم الجمعية', slot(p.associationName)),
      ('اسم الحوض', slot(p.basinName)),
      ('رقم الأرض', slot(p.landNumber)),
      ('فدان', _formatNumber(p.feddan) ?? FieldRow.emptyPlaceholder),
      ('قيراط', _formatNumber(p.qirat) ?? FieldRow.emptyPlaceholder),
      ('سهم', _formatNumber(p.sahm) ?? FieldRow.emptyPlaceholder),
      (
        'المساحة بالمتر',
        _formatNumber(p.totalSqm) ?? FieldRow.emptyPlaceholder,
      ),
      ('نوع الزرع', slot(p.cropType)),
      ('ملاحظات', slot(p.notes)),
      ('نوع الائتمان', creditSentence.isEmpty ? p.creditType : creditSentence),
    ];

    return fields.map((final (String, String) f) => '${f.$1}: ${f.$2},').join('\n');
  }
}

/// Lays [children] out as a wrap that adapts to the available width: one
/// column on phones, two on tablets, three on laptop/desktop — keeps a
/// card with many fields short instead of one long scrolling list.
class _ResponsiveFieldsWrap extends StatelessWidget {
  const _ResponsiveFieldsWrap({required this.children});

  final List<Widget> children;

  static const double _spacing = 8;

  @override
  Widget build(final BuildContext context) {
    return LayoutBuilder(
      builder: (final BuildContext context, final BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int columns = width >= 900 ? 3 : (width >= 520 ? 2 : 1);
        final double itemWidth = columns == 1
            ? width
            : (width - _spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final Widget child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

/// Collapsed-by-default section for the less-frequently-needed fields
/// (المديرية/الإدارة/كود الحوض/نوع الاستخدام), toggled independently per
/// card so stacking many cards on the detail screen doesn't overwhelm the
/// view by default.
class _SeeMoreSection extends StatefulWidget {
  const _SeeMoreSection({required this.parcel, required this.onFieldChanged});

  final Parcel parcel;
  final void Function(Parcel updated) onFieldChanged;

  @override
  State<_SeeMoreSection> createState() => _SeeMoreSectionState();
}

class _SeeMoreSectionState extends State<_SeeMoreSection> {
  bool _expanded = false;

  Future<void> _editText(
    final BuildContext context, {
    required final String title,
    required final String initialValue,
    required final Parcel Function(String value) apply,
  }) async {
    final String? value = await showTextInputDialog(
      context,
      title: title,
      initialValue: initialValue,
    );
    if (value == null) return;
    widget.onFieldChanged(apply(value));
  }

  Future<void> _editDropdown(
    final BuildContext context, {
    required final String title,
    required final String? initialValue,
    required final List<String> options,
    required final Parcel Function(String? value) apply,
    final bool allowClear = true,
  }) async {
    final ChoiceDialogResult<String>? result = await showChoiceDialog<String>(
      context,
      title: title,
      options: [
        for (final String option in options)
          ChoiceOption<String>(value: option, label: option),
      ],
      selected: initialValue,
      clearLabel: allowClear ? '—' : null,
    );
    if (result == null) return;
    widget.onFieldChanged(apply(result.isClear ? null : result.value));
  }

  @override
  Widget build(final BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _expanded
                      ? 'holdings.detail.see_less'.tr()
                      : 'holdings.detail.see_more'.tr(),
                  style: AppTextStyles.font12Bold.copyWith(
                    color: AppColors.primary200,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary200,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _expanded
              ? _ResponsiveFieldsWrap(
                  children: [
                    FieldRow(
                      label: 'المديرية',
                      value: widget.parcel.directorate,
                      onEdit: () => _editText(
                        context,
                        title: 'المديرية',
                        initialValue: widget.parcel.directorate ?? '',
                        apply: (final String v) => widget.parcel.copyWith(
                          directorate: v.isEmpty ? null : v,
                        ),
                      ),
                    ),
                    FieldRow(
                      label: 'الإدارة',
                      value: widget.parcel.administration,
                      onEdit: () => _editText(
                        context,
                        title: 'الإدارة',
                        initialValue: widget.parcel.administration ?? '',
                        apply: (final String v) => widget.parcel.copyWith(
                          administration: v.isEmpty ? null : v,
                        ),
                      ),
                    ),
                    FieldRow(
                      label: 'كود الحوض',
                      value: widget.parcel.basinCode,
                      onEdit: () => _editText(
                        context,
                        title: 'كود الحوض',
                        initialValue: widget.parcel.basinCode ?? '',
                        apply: (final String v) => widget.parcel.copyWith(
                          basinCode: v.isEmpty ? null : v,
                        ),
                      ),
                    ),
                    FieldRow(
                      label: 'نوع الاستخدام',
                      value: widget.parcel.usageType,
                      onEdit: () => _editDropdown(
                        context,
                        title: 'نوع الاستخدام',
                        initialValue: widget.parcel.usageType,
                        options: Parcel.usageTypeOptions,
                        allowClear: false,
                        apply: (final String? v) => widget.parcel.copyWith(
                          usageType: v ?? Parcel.defaultUsageType,
                        ),
                      ),
                    ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
