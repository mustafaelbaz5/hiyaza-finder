import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/ui/dialogs/choice_dialog.dart';
import '../../../../core/widgets/ui/dialogs/text_input_dialog.dart';
import '../../../cities/data/model/association_type.dart';
import '../../data/local/credit_type_notes_sync.dart';
import '../../data/local/field_change_tracker.dart';
import '../../data/local/usage_type_notes_sync.dart';
import '../../data/model/parcel.dart';
import '../../data/model/usage_type.dart';
import 'delegate_owner_dialog.dart';
import 'field_row.dart';
import 'ownership_toggle.dart';
import 'toggle_field_row.dart';

/// Keeps secondary administrative fields collapsed by default so the detail
/// screen stays compact while every field remains available.
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

  /// مفوض asks for the new اسم المالك up front (must differ from اسم
  /// الحائز) and, on confirm, sets `owner_name` and appends
  /// "مفوض عنه {holder}" to ملاحظات — same flow `AddRecordScreen` uses,
  /// so Detail Screen's toggle can't silently skip the dialog+validation
  /// (APP_UPDATES_CLAUDE.md § 3 Definition of Done).
  Future<void> _enableDelegate(final BuildContext context) async {
    final String? newOwnerName = await showDelegateOwnerDialog(
      context,
      holderName: widget.parcel.holderName ?? '',
    );
    if (newOwnerName == null) return;

    final String delegateNote = 'holdings.delegate.auto_note'
        .tr(namedArgs: {'holder': widget.parcel.holderName ?? ''});
    widget.onFieldChanged(
      widget.parcel.copyWith(
        isDelegate: true,
        ownerName: newOwnerName,
        notes: widget.parcel.notes.contains(delegateNote)
            ? widget.parcel.notes
            : <String>[...widget.parcel.notes, delegateNote],
      ),
    );
  }

  /// إلغاء المفوض reverts اسم المالك to اسم الحائز and strips the
  /// auto-added "مفوض عنه ..." note.
  void _disableDelegate() {
    widget.onFieldChanged(
      widget.parcel.copyWith(
        isDelegate: false,
        ownerName: widget.parcel.holderName,
        notes: widget.parcel.notes
            .where((final String n) => !n.startsWith('مفوض عنه'))
            .toList(),
      ),
    );
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
    final String label = _expanded
        ? 'holdings.detail.see_less'.tr()
        : 'holdings.detail.see_more'.tr();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPrimaryFields(context),
        verticalSpacing(8),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(Icons.tune_rounded,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(label,
                        style: Theme.of(context).textTheme.labelLarge)),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.expand_more_rounded),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: _expanded ? _buildFields(context) : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _pairRow(final Widget left, final Widget right) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          horizontalSpacing(8),
          Expanded(child: right),
        ],
      );

  Widget _buildPrimaryFields(final BuildContext context) {
    final Widget usage = FieldRow(
      label: 'holdings.fields.usage_type'.tr(),
      value: widget.parcel.usageType,
      isModified: _isModified((final p) => p.usageType),
      onEdit: () => _editDropdown(
        context,
        title: 'holdings.fields.usage_type'.tr(),
        initialValue: widget.parcel.usageType,
        options: Parcel.usageTypeOptions,
        allowClear: false,
        apply: (final String? value) => UsageTypeNotesSync.applyUsageTypeChange(
          widget.parcel,
          value ?? Parcel.defaultUsageType,
        ),
      ),
    );
    final Widget inheritance = ToggleFieldRow(
      label: 'holdings.fields.inheritance'.tr(),
      value: widget.parcel.isInheritance,
      activeLabel: 'holdings.fields.inheritance'.tr(),
      inactiveLabel: 'holdings.fields.not_inheritance'.tr(),
      isModified: _isModified((final p) => p.isInheritance),
      onChanged: (final bool value) => widget.onFieldChanged(
        widget.parcel.copyWith(isInheritance: value),
      ),
    );
    final Widget delegate = ToggleFieldRow(
      label: 'holdings.fields.delegate'.tr(),
      value: widget.parcel.isDelegate,
      activeLabel: 'holdings.fields.delegate'.tr(),
      inactiveLabel: 'holdings.fields.not_delegate'.tr(),
      isModified: _isModified((final p) => p.isDelegate),
      onChanged: (final bool value) =>
          value ? _enableDelegate(context) : _disableDelegate(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        usage,
        verticalSpacing(8),
        _pairRow(inheritance, delegate),
      ],
    );
  }

  /// Secondary fields stay behind See More to keep the primary detail card
  /// compact. The toggle row intentionally comes before its linked
  /// ownership/reform field so the relationship is clear to the user.
  Widget _buildFields(final BuildContext context) {
    final Widget basinCode = FieldRow(
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
    );
    final bool isReformCity =
        widget.associationType == AssociationType.agriculturalReform;
    final Widget ownership = isReformCity
        ? FieldRow(
            label: 'holdings.fields.reform_type'.tr(),
            value: widget.parcel.reformType,
            isModified: _isModified((final p) => p.reformType),
            onEdit: () => _editDropdown(
              context,
              title: 'holdings.fields.reform_type'.tr(),
              initialValue: widget.parcel.reformType,
              options: Parcel.reformTypeOptions,
              allowClear: false,
              apply: (final String? v) =>
                  CreditTypeNotesSync.applyReformNoteSelected(
                widget.parcel,
                v ?? Parcel.defaultReformType,
              ),
            ),
          )
        : OwnershipToggle(
            isAwqaf: widget.parcel.creditType != Parcel.defaultCreditType,
            onChanged: (final bool value) => widget.onFieldChanged(
              CreditTypeNotesSync.applyOwnershipToggle(widget.parcel, value),
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldRow(
          label: 'holdings.fields.association_name'.tr(),
          value: widget.parcel.associationName,
          isModified: _isModified((final p) => p.associationName),
          onEdit: () => _editText(
            context,
            title: 'holdings.fields.association_name'.tr(),
            initialValue: widget.parcel.associationName ?? '',
            apply: (final String v) => widget.parcel.copyWith(
              associationName: v.isEmpty ? null : v,
            ),
          ),
        ),
        verticalSpacing(8),
        ownership,
        verticalSpacing(8),
        basinCode,
        verticalSpacing(8),
        _pairRow(
          FieldRow(
            label: 'holdings.detail.holdings_count'.tr(),
            value: widget.parcel.holdingsCount?.toString() ?? '-',
          ),
          FieldRow(
            label: 'holdings.fields.land_number'.tr(),
            value: widget.parcel.landNumber,
            isModified: _isModified((final p) => p.landNumber),
            onEdit: () => _editText(
              context,
              title: 'holdings.fields.land_number'.tr(),
              initialValue: widget.parcel.landNumber ?? '',
              apply: (final String v) => widget.parcel.copyWith(
                landNumber: v.isEmpty ? null : v,
              ),
            ),
          ),
        ),
        if (UsageType.fromLabel(widget.parcel.usageType) ==
            UsageType.agricultural) ...[
          verticalSpacing(8),
          FieldRow(
            label: 'holdings.fields.growth_stages'.tr(),
            value: widget.parcel.growthStages,
            isModified: _isModified((final p) => p.growthStages),
            onEdit: () => _editDropdown(
              context,
              title: 'holdings.fields.growth_stages'.tr(),
              initialValue: widget.parcel.growthStages,
              options: Parcel.growthStageOptions,
              allowClear: false,
              apply: (final String? v) => widget.parcel.copyWith(
                growthStages: v ?? Parcel.defaultGrowthStage,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
