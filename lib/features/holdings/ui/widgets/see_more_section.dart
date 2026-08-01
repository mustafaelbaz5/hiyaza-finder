import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hiyaza_finder/core/themes/app_colors.dart';
import 'package:hiyaza_finder/core/themes/app_text_styles.dart';
import 'package:hiyaza_finder/core/widgets/ui/dialogs/choice_dialog.dart';
import 'package:hiyaza_finder/core/widgets/ui/dialogs/text_input_dialog.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/city_type.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/field_row.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/responsive_fields_wrap.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/toggle_field_row.dart';

/// Collapsed-by-default section for the less-frequently-needed fields
/// (المديرية/الإدارة/كود الحوض/نوع الاستخدام), toggled independently per
/// card so stacking many cards on the detail screen doesn't overwhelm the
/// view by default.
class SeeMoreSection extends StatefulWidget {
  const SeeMoreSection({
    super.key,
    required this.parcel,
    required this.onFieldChanged,
    this.hideCreditType = false,
    this.cityType = CityType.unspecified,
  });

  final Parcel parcel;
  final void Function(Parcel updated) onFieldChanged;

  /// Omits نوع الائتمان entirely (no row, no reserved space) for
  /// الإصلاح الزراعي cities, where the field has no meaning.
  final bool hideCreditType;

  /// The active city's detected agricultural system — determines whether to
  /// display نوع الائتمان (agricultural credit) or نوع الإصلاح (reform).
  final CityType cityType;

  @override
  State<SeeMoreSection> createState() => SeeMoreSectionState();
}

class SeeMoreSectionState extends State<SeeMoreSection> {
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
        for (final String option in options) ChoiceOption<String>(value: option, label: option),
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
                  _expanded ? 'holdings.detail.see_less'.tr() : 'holdings.detail.see_more'.tr(),
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
              ? ResponsiveFieldsWrap(
                  children: [
                    ToggleFieldRow(
                      label: 'وراثة',
                      value: widget.parcel.isInheritance,
                      activeLabel: 'وراثة',
                      inactiveLabel: 'ليست وراثة',
                      onChanged: (final bool v) => widget.onFieldChanged(
                        widget.parcel.copyWith(isInheritance: v),
                      ),
                    ),
                    ToggleFieldRow(
                      label: 'مفوض',
                      value: widget.parcel.isDelegate,
                      activeLabel: 'مفوض',
                      inactiveLabel: 'غير مفوض',
                      onChanged: (final bool v) => widget.onFieldChanged(
                        widget.parcel.copyWith(isDelegate: v),
                      ),
                    ),
                    if (widget.cityType == CityType.agriculturalReform)
                      FieldRow(
                        label: 'نوع الإصلاح',
                        value: widget.parcel.reformType,
                        onEdit: () => _editDropdown(
                          context,
                          title: 'نوع الإصلاح',
                          initialValue: widget.parcel.reformType,
                          options: Parcel.reformTypeOptions,
                          allowClear: false,
                          apply: (final String? v) => widget.parcel.copyWith(
                            reformType: v ?? Parcel.defaultReformType,
                          ),
                        ),
                      )
                    else if (!widget.hideCreditType)
                      FieldRow(
                        label: 'نوع الائتمان',
                        value: widget.parcel.creditType,
                        onEdit: () => _editDropdown(
                          context,
                          title: 'نوع الائتمان',
                          initialValue: widget.parcel.creditType,
                          options: Parcel.creditTypeOptions,
                          allowClear: false,
                          apply: (final String? v) => widget.parcel.copyWith(
                            creditType: v ?? Parcel.defaultCreditType,
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
                    FieldRow(
                      label: 'كود الحوض',
                      value: widget.parcel.basinCode,
                      placeholder: '-1',
                      onEdit: () => _editText(
                        context,
                        title: 'كود الحوض',
                        initialValue: widget.parcel.basinCode ?? '',
                        apply: (final String v) => widget.parcel.copyWith(
                          basinCode: v.isEmpty ? null : v,
                        ),
                      ),
                    ),
                    FieldRow(label: 'المديرية', value: widget.parcel.directorate),
                    FieldRow(
                      label: 'الإدارة',
                      value: widget.parcel.administration,
                    ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
