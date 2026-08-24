import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/ui/dialogs/choice_dialog.dart';
import '../../../../core/widgets/ui/dialogs/text_input_dialog.dart';
import '../../../cities/data/model/association_type.dart';
import '../../data/local/clipboard_formatter.dart';
import '../../data/local/credit_type_notes_sync.dart';
import '../../data/local/field_change_tracker.dart';
import '../../data/local/usage_type_notes_sync.dart';
import '../../data/model/parcel.dart';
import '../../data/model/usage_type.dart';
import 'delegate_owner_dialog.dart';
import 'field_row.dart';
import 'ownership_toggle.dart';
import 'toggle_field_row.dart';

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

  static const ClipboardFormatter _formatter = ClipboardFormatter();

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
              ? _buildFields(context)
              : const SizedBox(width: double.infinity),
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

  /// Exact row layout per `REFACTOR_ROADMAP.md` Phase 11 §5:
  /// Row 1 ورثة/مفوض, Row 2 كود الحوض/نوع الائتمان أو الإصلاح, Row 3
  /// مراحل النمو (full-width), Row 4 المديرية/الإدارة. اسم الجمعية (moved
  /// here from the primary area, §4) and نوع الاستخدام (kept, not in the
  /// spec's 4 named rows) come after as their own full-width rows rather
  /// than inventing a 5th/6th named pairing the spec didn't specify.
  Widget _buildFields(final BuildContext context) {
    final Widget inheritance = ToggleFieldRow(
      label: 'holdings.fields.inheritance'.tr(),
      value: widget.parcel.isInheritance,
      activeLabel: 'holdings.fields.inheritance'.tr(),
      inactiveLabel: 'holdings.fields.not_inheritance'.tr(),
      isModified: _isModified((final p) => p.isInheritance),
      onChanged: (final bool v) => widget.onFieldChanged(
        widget.parcel.copyWith(isInheritance: v),
      ),
    );
    final Widget delegate = ToggleFieldRow(
      label: 'holdings.fields.delegate'.tr(),
      value: widget.parcel.isDelegate,
      activeLabel: 'holdings.fields.delegate'.tr(),
      inactiveLabel: 'holdings.fields.not_delegate'.tr(),
      isModified: _isModified((final p) => p.isDelegate),
      onChanged: (final bool v) =>
          v ? _enableDelegate(context) : _disableDelegate(),
    );
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
    // نوع الائتمان/نوع الإصلاح are no longer a visible dropdown field —
    // credit cities get the ملك/أوقاف toggle below (drives `creditType` +
    // the أوقاف note automatically); reform cities show nothing here at
    // all, since نوع الإصلاح is now selected purely via the quick-select
    // notes (Credit/Reform Type Logic prompt).
    final bool isReformCity =
        widget.associationType == AssociationType.agriculturalReform;
    final Widget? ownershipToggle = isReformCity
        ? null
        : OwnershipToggle(
            isAwqaf: widget.parcel.creditType != Parcel.defaultCreditType,
            onChanged: (final bool isAwqaf) => widget.onFieldChanged(
              CreditTypeNotesSync.applyOwnershipToggle(
                widget.parcel,
                isAwqaf,
              ),
            ),
          );
    final Widget directorate = FieldRow(
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
    );
    final Widget administration = FieldRow(
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
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pairRow(inheritance, delegate),
        verticalSpacing(8),
        basinCode,
        if (ownershipToggle != null) ...[
          verticalSpacing(8),
          ownershipToggle,
        ],
        if (UsageType.fromLabel(widget.parcel.usageType) ==
            UsageType.agricultural) ...[
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
          verticalSpacing(8),
        ],
        // Moved here from the primary card area (UI/UX Updates prompt
        // "Change 3") — placed right after نوع المحصول/مراحل النمو.
        FieldRow(
          label: 'holdings.fields.area_sqm'.tr(),
          value: _formatter.formatNumber(widget.parcel.totalSqm),
          isModified: _isModified((final p) => p.totalSqm),
        ),
        verticalSpacing(8),
        // Moved here from the primary card area (UI/UX redesign) — grouped
        // with the other parcel-identity/measurement fields above rather
        // than the administrative المديرية/الإدارة pair below.
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
        verticalSpacing(8),
        _pairRow(directorate, administration),
        verticalSpacing(8),
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
            apply: (final String? v) => UsageTypeNotesSync.applyUsageTypeChange(
              widget.parcel,
              v ?? Parcel.defaultUsageType,
            ),
          ),
        ),
      ],
    );
  }
}
