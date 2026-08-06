import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hiyaza_finder/core/themes/app_colors.dart';
import 'package:hiyaza_finder/core/themes/app_text_styles.dart';
import 'package:hiyaza_finder/core/widgets/ui/dialogs/choice_dialog.dart';
import 'package:hiyaza_finder/core/widgets/ui/dialogs/text_input_dialog.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/association_type.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/domain/services/field_change_tracker.dart';
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
    this.originalParcel,
    this.hideCreditType = false,
    this.associationType,
  });

  final Parcel parcel;
  final void Function(Parcel updated) onFieldChanged;

  /// [parcel]'s pre-edit value — see `ParcelDetailCard.originalParcel` for
  /// the full rationale; each field here compares itself the same way.
  final Parcel? originalParcel;

  /// Omits نوع الائتمان entirely (no row, no reserved space) for
  /// الإصلاح الزراعي cities, where the field has no meaning.
  final bool hideCreditType;

  /// The active city's association type, read from
  /// `cities.association_type` — determines whether to display نوع الائتمان
  /// (agricultural credit) or نوع الإصلاح (reform). `null` when the
  /// dashboard hasn't set it for this city; treated like
  /// `agriculturalCredit` (shows نوع الائتمان) so an unset value never
  /// silently hides a field that might matter.
  final AssociationType? associationType;

  @override
  State<SeeMoreSection> createState() => SeeMoreSectionState();
}

class SeeMoreSectionState extends State<SeeMoreSection> {
  bool _expanded = false;

  /// See `ParcelDetailCard._isModified` — same comparison, against
  /// [SeeMoreSection.originalParcel] instead.
  bool _isModified<T>(final T Function(Parcel p) current) {
    final Parcel? original = widget.originalParcel;
    if (original == null) return false;
    return FieldChangeTracker.isModified(
      current(widget.parcel),
      current(original),
    );
  }

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
              ? ResponsiveFieldsWrap(
                  children: [
                    ToggleFieldRow(
                      label: 'holdings.fields.inheritance'.tr(),
                      value: widget.parcel.isInheritance,
                      activeLabel: 'holdings.fields.inheritance'.tr(),
                      inactiveLabel: 'holdings.fields.not_inheritance'.tr(),
                      isModified: _isModified((final p) => p.isInheritance),
                      onChanged: (final bool v) => widget.onFieldChanged(
                        widget.parcel.copyWith(isInheritance: v),
                      ),
                    ),
                    ToggleFieldRow(
                      label: 'holdings.fields.delegate'.tr(),
                      value: widget.parcel.isDelegate,
                      activeLabel: 'holdings.fields.delegate'.tr(),
                      inactiveLabel: 'holdings.fields.not_delegate'.tr(),
                      isModified: _isModified((final p) => p.isDelegate),
                      onChanged: (final bool v) => widget.onFieldChanged(
                        widget.parcel.copyWith(isDelegate: v),
                      ),
                    ),
                    if (widget.associationType ==
                        AssociationType.agriculturalReform)
                      FieldRow(
                        label: 'holdings.fields.reform_type'.tr(),
                        value: widget.parcel.reformType,
                        isModified: _isModified((final p) => p.reformType),
                        onEdit: () => _editDropdown(
                          context,
                          title: 'holdings.fields.reform_type'.tr(),
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
                        label: 'holdings.fields.credit_type'.tr(),
                        value: widget.parcel.creditType,
                        isModified: _isModified((final p) => p.creditType),
                        onEdit: () => _editDropdown(
                          context,
                          title: 'holdings.fields.credit_type'.tr(),
                          initialValue: widget.parcel.creditType,
                          options: Parcel.creditTypeOptions,
                          allowClear: false,
                          apply: (final String? v) => widget.parcel.copyWith(
                            creditType: v ?? Parcel.defaultCreditType,
                          ),
                        ),
                      ),
                    FieldRow(
                      label: 'holdings.fields.usage_type'.tr(),
                      value: widget.parcel.usageType,
                      isModified: _isModified((final p) => p.usageType),
                      onEdit: () => _editDropdown(
                        context,
                        title: 'holdings.fields.usage_type'.tr(),
                        initialValue: widget.parcel.usageType,
                        options: Parcel.usageTypeOptions,
                        allowClear: false,
                        apply: (final String? v) => widget.parcel.copyWith(
                          usageType: v ?? Parcel.defaultUsageType,
                        ),
                      ),
                    ),
                    FieldRow(
                      label: 'holdings.fields.basin_code'.tr(),
                      value: widget.parcel.basinCode,
                      placeholder: '-1',
                      isModified: _isModified((final p) => p.basinCode),
                      onEdit: () => _editText(
                        context,
                        title: 'holdings.fields.basin_code'.tr(),
                        initialValue: widget.parcel.basinCode ?? '',
                        apply: (final String v) => widget.parcel.copyWith(
                          basinCode: v.isEmpty ? null : v,
                        ),
                      ),
                    ),
                    FieldRow(
                      label: 'holdings.fields.directorate'.tr(),
                      value: widget.parcel.directorate,
                      isModified: _isModified((final p) => p.directorate),
                      onEdit: () => _editText(
                        context,
                        title: 'holdings.fields.directorate'.tr(),
                        initialValue: widget.parcel.directorate ?? '',
                        apply: (final String v) => widget.parcel.copyWith(
                          directorate: v.isEmpty ? null : v,
                        ),
                      ),
                    ),
                    FieldRow(
                      label: 'holdings.fields.administration'.tr(),
                      value: widget.parcel.administration,
                      isModified: _isModified((final p) => p.administration),
                      onEdit: () => _editText(
                        context,
                        title: 'holdings.fields.administration'.tr(),
                        initialValue: widget.parcel.administration ?? '',
                        apply: (final String v) => widget.parcel.copyWith(
                          administration: v.isEmpty ? null : v,
                        ),
                      ),
                    ),
                    FieldRow(
                      label: 'holdings.fields.holder_name_farmer_card'.tr(),
                      value: widget.parcel.holderNameFarmerCard,
                      isModified:
                          _isModified((final p) => p.holderNameFarmerCard),
                      onEdit: () => _editText(
                        context,
                        title: 'holdings.fields.holder_name_farmer_card'.tr(),
                        initialValue: widget.parcel.holderNameFarmerCard ?? '',
                        apply: (final String v) => widget.parcel.copyWith(
                          holderNameFarmerCard: v.isEmpty ? null : v,
                        ),
                      ),
                    ),
                    FieldRow(
                      label: 'holdings.fields.owner_name_farmer_card'.tr(),
                      value: widget.parcel.ownerNameFarmerCard,
                      isModified:
                          _isModified((final p) => p.ownerNameFarmerCard),
                      onEdit: () => _editText(
                        context,
                        title: 'holdings.fields.owner_name_farmer_card'.tr(),
                        initialValue: widget.parcel.ownerNameFarmerCard ?? '',
                        apply: (final String v) => widget.parcel.copyWith(
                          ownerNameFarmerCard: v.isEmpty ? null : v,
                        ),
                      ),
                    ),
                    FieldRow(
                      label: 'holdings.fields.growth_stages'.tr(),
                      value: widget.parcel.growthStages,
                      isModified: _isModified((final p) => p.growthStages),
                      onEdit: () => _editText(
                        context,
                        title: 'holdings.fields.growth_stages'.tr(),
                        initialValue: widget.parcel.growthStages ?? '',
                        apply: (final String v) => widget.parcel.copyWith(
                          growthStages: v.isEmpty ? null : v,
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
