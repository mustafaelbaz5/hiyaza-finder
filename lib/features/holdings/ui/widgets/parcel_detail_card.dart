import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../data/models/parcel.dart';
import '../../logic/services/area_calculator.dart';
import 'border_compass.dart';
import 'field_edit_dialogs.dart';
import 'field_row.dart';

/// One parcel's full record: border compass + field rows + copy-all.
/// Detail screens stack one of these per parcel belonging to a holding.
class ParcelDetailCard extends StatelessWidget {
  const ParcelDetailCard({
    super.key,
    required this.parcel,
    required this.resolveBorder,
    required this.onNavigate,
    required this.onUnresolvedBorder,
    required this.onFieldChanged,
    this.onEdit,
    this.isEdited = false,
    this.animationDelay = Duration.zero,
  });

  final Parcel parcel;
  final String? Function(String borderText) resolveBorder;
  final void Function(String holdingId) onNavigate;
  final void Function(String borderText) onUnresolvedBorder;

  /// Called with a fully-updated [Parcel] whenever a single field is saved
  /// via its inline pencil-icon editor.
  final void Function(Parcel updated) onFieldChanged;
  final VoidCallback? onEdit;
  final bool isEdited;
  final Duration animationDelay;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Container(
      padding: EdgeInsets.all(rw(16)),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextButton.outlined(
            text: 'holdings.detail.copy_all'.tr(),
            prefixIcon: const Icon(
              Icons.copy_all_rounded,
              color: AppColors.primary200,
            ),
            onPressed: () => _copyAll(context),
          ),
          verticalSpacing(16),
          if (onEdit != null) ...<Widget>[
            Row(
              children: <Widget>[
                if (isEdited)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
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
                          size: 16,
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
                const Spacer(),
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary50.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: AppColors.primary200,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'holdings.edit.edit_button'.tr(),
                          style: AppTextStyles.font12Bold.copyWith(
                            color: AppColors.primary200,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            verticalSpacing(12),
          ],
          BorderCompass(
            holdingId: parcel.holdingId,
            north: parcel.borderNorth,
            south: parcel.borderSouth,
            east: parcel.borderEast,
            west: parcel.borderWest,
            resolveBorder: resolveBorder,
            onNavigate: onNavigate,
            onUnresolved: onUnresolvedBorder,
          ),
          verticalSpacing(16),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
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
                    apply: (final String? v) => parcel.copyWith(
                      creditType: v ?? Parcel.defaultCreditType,
                    ),
                  ),
                ),
                FieldRow(
                  label: 'وراثة',
                  value: parcel.isInheritance ? 'وراثة' : 'ليست وراثة',
                  showDivider: false,
                  onEdit: () => _editSwitch(context),
                ),
              ],
            ),
          ),
          verticalSpacing(8),
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
    final String? value = await showTextFieldEditDialog(
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
    final String? value = await showDropdownFieldEditDialog(
      context,
      title: title,
      initialValue: initialValue,
      options: options,
      allowClear: allowClear,
    );
    if (value == null) return;
    onFieldChanged(apply(value.isEmpty ? null : value));
  }

  Future<void> _editSwitch(final BuildContext context) async {
    final bool? value = await showSwitchFieldEditDialog(
      context,
      title: 'وراثة',
      initialValue: parcel.isInheritance,
    );
    if (value == null) return;
    onFieldChanged(parcel.copyWith(isInheritance: value));
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
    String slot(final String? v) => (v == null || v.trim().isEmpty) ? '' : v.trim();

    final String holderSlot = p.isInheritance
        ? '(ورثة) ${slot(p.holderName)}'
        : slot(p.holderName);
    final String nationalIdSlot = slot(p.nationalId).isEmpty
        ? '11111111111111'
        : slot(p.nationalId);
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
      ('فدان', _formatNumber(p.feddan) ?? ''),
      ('قيراط', _formatNumber(p.qirat) ?? ''),
      ('سهم', _formatNumber(p.sahm) ?? ''),
      ('المساحة بالمتر', _formatNumber(p.totalSqm) ?? ''),
      ('نوع الزرع', slot(p.cropType)),
      ('ملاحظات', slot(p.notes)),
      ('نوع الائتمان', creditSentence.isEmpty ? p.creditType : creditSentence),
    ];

    return fields.map((final (String, String) f) => '${f.$1}: ${f.$2},').join('\n');
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
    final String? value = await showTextFieldEditDialog(
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
    final String? value = await showDropdownFieldEditDialog(
      context,
      title: title,
      initialValue: initialValue,
      options: options,
      allowClear: allowClear,
    );
    if (value == null) return;
    widget.onFieldChanged(apply(value.isEmpty ? null : value));
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _expanded
                      ? 'holdings.detail.see_less'.tr()
                      : 'holdings.detail.see_more'.tr(),
                  style: AppTextStyles.font14SemiBold.copyWith(
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
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _expanded
              ? Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
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
                        showDivider: false,
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
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
