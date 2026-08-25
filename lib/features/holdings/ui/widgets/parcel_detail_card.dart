import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/errors/error_message_resolver.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/ui/dialogs/app_dialogs.dart';
import '../../../../core/widgets/ui/dialogs/choice_dialog.dart';
import '../../../../core/widgets/ui/dialogs/text_input_dialog.dart';
import '../../../cities/data/model/association_type.dart';
import '../../../crop_type/ui/widgets/crop_type_picker.dart';
import '../../data/local/area_calculator.dart';
import '../../data/local/clipboard_formatter.dart';
import '../../data/local/credit_type_notes_sync.dart';
import '../../data/local/field_change_tracker.dart';
import '../../data/local/usage_type_notes_sync.dart';
import '../../data/model/parcel.dart';
import '../../data/model/usage_type.dart';
import '../../data/repo/holdings_repository.dart';
import 'basin_picker.dart';
import 'border_compass.dart';
import 'copy_all_button.dart';
import 'field_edit_dialogs.dart';
import 'field_row.dart';
import 'notes_field.dart';
import 'parcel_detail_header.dart';
import 'required_field_gaps.dart';
import 'see_more_section.dart';

class ParcelDetailCard extends StatelessWidget {
  const ParcelDetailCard({
    super.key,
    required this.parcel,
    required this.onFieldChanged,
    this.originalParcel,
    this.isNew = false,
    this.hideCreditType = false,
    this.associationType,
    this.animationDelay = Duration.zero,
    this.resolveBorderMatch,
    this.onDelete,
    this.onReopen,
    this.onCompleted,
    this.isDeleting = false,
    this.isReopening = false,
    this.onReviewBusyChanged,
  });

  final Parcel parcel;
  final void Function(Parcel updated) onFieldChanged;
  final Parcel? originalParcel;
  final bool isNew;
  final VoidCallback? onDelete;
  final bool hideCreditType;
  final AssociationType? associationType;
  final Duration animationDelay;
  final Parcel? Function(String? borderText)? resolveBorderMatch;
  final VoidCallback? onReopen;

  /// Passed straight through to [ParcelDetailTopRow] (`REFACTOR_ROADMAP.md`
  /// Phase 21) — the caller tracks which parcel's delete/reopen call is
  /// currently in flight (`DetailScreen._busyParcelIds`), since that's
  /// screen-level state this stateless card has no way to know on its own.
  final bool isDeleting;
  final bool isReopening;

  /// Fired by [_copyId] once `setParcelCompleted` is server-confirmed —
  /// deliberately separate from [onFieldChanged] (`REFACTOR_ROADMAP.md`
  /// Phase 20): reflecting a completion into the caller's local state must
  /// never depend on a second, unrelated `updateParcel`/edit-overlay write
  /// succeeding, or route through a handler built for field edits (wrong
  /// snackbar, wrong `_isBusy` coupling, and a failure there could mask an
  /// already-successful review). Falls back to [onFieldChanged] if unset,
  /// so callers that haven't been updated yet keep working.
  final void Function(Parcel updated)? onCompleted;

  /// Reports when [_copyId]'s server write starts/stops being in flight —
  /// lets `DetailScreen` fold Copy ID's busy window into the same
  /// `_busyParcelIds` tracking `isDeleting`/`isReopening` already use, so a
  /// same-parcel Reopen/Delete tap can't race a Copy ID write still in
  /// flight. The chip's own spinner (driven by [_ReviewIdChipState]'s local
  /// `_isLoading`) is unaffected — this is purely so the *parent* can see
  /// the same window, not a replacement for the chip's own feedback.
  final void Function(bool isBusy)? onReviewBusyChanged;

  static const ClipboardFormatter _formatter = ClipboardFormatter();

  bool _isModified<T>(final T Function(Parcel p) current) {
    final Parcel? original = originalParcel;
    if (original == null) return false;
    return FieldChangeTracker.isModified(current(parcel), current(original));
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final bool isAdded =
        parcel.isFieldAdded || parcel.sourceAddedHoldingId != null || isNew;
    final bool isCompleted = parcel.completedAt != null;
    // Completed parcels are locked (`REFACTOR_ROADMAP.md` Phase 10 §9): a
    // stronger, darker treatment than the old subtle-fade look, and fields
    // stop being directly tappable/editable — إعادة الفتح (top row, kept
    // OUTSIDE the ignore-pointer scope below) is the only way back into an
    // editable state, communicating that reopening is a deliberate,
    // required step rather than something a stray tap on a field could
    // bypass.
    final Widget topRow = ParcelDetailTopRow(
      isAdded: isAdded,
      isReviewed: isCompleted,
      onReopen: onReopen,
      onDelete: onDelete,
      onDeleteConfirmed: () => _confirmDelete(context),
      isInheritance: parcel.isInheritance,
      isDelegate: parcel.isDelegate,
      isDeleting: isDeleting,
      isReopening: isReopening,
    );
    final Widget body = Opacity(
      opacity: isCompleted ? 0.55 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action-area order is fixed (`REFACTOR_ROADMAP.md` Phase 11
          // §3): status/badges → boundaries → Copy ID → Copy All. The
          // large "تم مراجعة القطعة" banner that used to sit here for a
          // completed parcel was removed (`REFACTOR_ROADMAP.md` Phase 18)
          // — the small "تم المراجعة" `StatusBadge` in [topRow] already
          // says this, and the card's own locked styling (stronger tint/
          // border below) carries the rest; a second full banner repeating
          // the same fact was redundant weight on an already-done record.
          if (isAdded) ...[
            verticalSpacing(8),
            _AddedByBanner(parcel: parcel),
          ],
          verticalSpacing(10),
          BorderCompass(
            holdingId: parcel.holdingId,
            north: parcel.borderNorth,
            south: parcel.borderSouth,
            east: parcel.borderEast,
            west: parcel.borderWest,
            onTapBorder: resolveBorderMatch == null
                ? null
                : (final String? borderText) =>
                    _openBorderPerson(context, borderText),
            isBorderNavigable: resolveBorderMatch == null
                ? null
                : (final String? borderText) =>
                    resolveBorderMatch!(borderText) != null,
          ),
          verticalSpacing(10),
          _ReviewIdChip(
            id: parcel.id,
            onCopy: _copyId,
            onBusyChanged: onReviewBusyChanged,
          ),
          verticalSpacing(10),
          CopyAllButton(onTap: () => _copyAll(context)),
          verticalSpacing(12),
          verticalSpacing(8),
          // Row 1: رقم الحيازة + عدد القطع share one row (`REFACTOR_ROADMAP.md`
          // Phase 10 §4) — every other primary field below gets its own
          // full-width row instead of a multi-column grid, since these are
          // the values field workers read/edit most and horizontal
          // compression made them harder to scan and tap accurately.
          Row(
            children: [
              Expanded(
                flex: parcel.holdingsCount != null ? 2 : 1,
                child: FieldRow(
                  label: 'holdings.detail.holding_id'.tr(),
                  value: parcel.isHoldingIdPending
                      ? 'holdings.detail.holding_id_pending'.tr()
                      : parcel.holdingId,
                  isModified: _isModified((final p) => p.holdingId),
                  onEdit: () => _editText(
                    context,
                    title: 'holdings.detail.holding_id'.tr(),
                    initialValue:
                        parcel.isHoldingIdPending ? '' : parcel.holdingId,
                    apply: (final String v) => parcel.copyWith(holdingId: v),
                  ),
                ),
              ),
              if (parcel.holdingsCount != null) ...[
                horizontalSpacing(8),
                Expanded(
                  child: FieldRow(
                    label: 'holdings.detail.holdings_count'.tr(),
                    value: parcel.holdingsCount.toString(),
                  ),
                ),
              ],
            ],
          ),
          verticalSpacing(8),
          FieldRow(
            label: 'holdings.fields.owner_name'.tr(),
            // ورثة prefix shown here matches `ClipboardFormatter`'s exact
            // "وارثه " rule (UI/UX Updates prompt "Change 2") — display
            // only, the edit dialog below still opens with the raw name.
            value: _formatter.displayOwnerName(parcel),
            isModified: _isModified((final p) => p.ownerName),
            onEdit: () => _editText(
              context,
              title: 'holdings.fields.owner_name'.tr(),
              initialValue: _formatter.effectiveOwnerName(parcel) ?? '',
              apply: (final String v) =>
                  parcel.copyWith(ownerName: v.isEmpty ? null : v),
            ),
          ),
          verticalSpacing(8),
          FieldRow(
            label: 'holdings.fields.holder_name'.tr(),
            // اسم الحائز is never prefixed (UI/UX Updates prompt "Change
            // 1"/"Change 2") — مفوض only ever shows up as a ملاحظات entry.
            value: _formatter.displayHolderName(parcel),
            isModified: _isModified((final p) => p.holderName),
            onEdit: () => _editText(
              context,
              title: 'holdings.fields.holder_name'.tr(),
              initialValue: parcel.holderName ?? '',
              apply: (final String v) =>
                  parcel.copyWith(holderName: v.isEmpty ? null : v),
            ),
          ),
          verticalSpacing(8),
          FieldRow(
            label: 'holdings.fields.national_id'.tr(),
            // Display-only fallback (UI/UX Updates prompt "Change 7") —
            // never written back to `Parcel.nationalId` itself; the edit
            // dialog below still opens with the real (possibly empty) value.
            value: _formatter.displayNationalId(parcel),
            isModified: _isModified((final p) => p.nationalId),
            onEdit: () => _editText(
              context,
              title: 'holdings.fields.national_id'.tr(),
              initialValue: parcel.nationalId ?? '',
              keyboardType: TextInputType.number,
              apply: (final String v) =>
                  parcel.copyWith(nationalId: v.isEmpty ? null : v),
            ),
          ),
          verticalSpacing(8),
          FieldRow(
            label: 'holdings.fields.basin_name'.tr(),
            value: parcel.basinName,
            isModified: _isModified((final p) => p.basinName),
            onEdit: () => _editBasin(context),
          ),
          verticalSpacing(8),
          FieldRow(
            label: 'holdings.fields.area'.tr(),
            value: _formatter.areaFraction(parcel),
            isModified: _isModified((final p) => p.feddan) ||
                _isModified((final p) => p.qirat) ||
                _isModified((final p) => p.sahm),
            onEdit: () => _editArea(context),
          ),
          verticalSpacing(8),
          // Moved here from See More — المساحة بالمتر sits with the rest
          // of the area info instead of being buried behind a second tap.
          FieldRow(
            label: 'holdings.fields.area_sqm'.tr(),
            value: _formatter.formatNumber(parcel.totalSqm),
            isModified: _isModified((final p) => p.totalSqm),
          ),
          if (UsageType.fromLabel(parcel.usageType) ==
              UsageType.agricultural) ...[
            verticalSpacing(8),
            FieldRow(
              label: 'holdings.fields.crop_type'.tr(),
              value: parcel.cropType,
              isModified: _isModified((final p) => p.cropType),
              onEdit: () => _editCropType(context),
            ),
          ],
          verticalSpacing(8),
          NotesField(
            notes: parcel.notes,
            isModified: _isModified((final p) => p.notes),
            associationType: associationType,
            onChanged: (final List<String> notes) =>
                onFieldChanged(parcel.copyWith(notes: notes)),
            onNoteAdded: (final String note) => onFieldChanged(
              Parcel.reformTypeOptions.contains(note)
                  ? CreditTypeNotesSync.applyReformNoteSelected(parcel, note)
                  : UsageTypeNotesSync.applyNoteAdded(parcel, note),
            ),
          ),
          verticalSpacing(12),
          verticalSpacing(8),
          SeeMoreSection(
            parcel: parcel,
            onFieldChanged: onFieldChanged,
            originalParcel: originalParcel,
            hideCreditType: hideCreditType,
            associationType: associationType,
          ),
        ],
      ),
    );

    // A completed parcel needs to read as clearly locked/done at a glance,
    // distinct from an active card, not just slightly faded
    // (`REFACTOR_ROADMAP.md` Phase 18) — a visibly grey-tinted surface plus
    // a solid (not translucent) grey border, rather than the previous
    // barely-there tint that looked close to a normal card.
    final Color lockedSurface = colors.textSecondary.withValues(alpha: 0.10);
    final Color lockedBorder = colors.textSecondary.withValues(alpha: 0.55);

    return Container(
      padding: EdgeInsets.all(rw(12)),
      decoration: BoxDecoration(
        color: isCompleted ? lockedSurface : colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted
              ? lockedBorder
              : isAdded
                  ? AppColors.blue200.withValues(alpha: 0.35)
                  : colors.border,
          width: isCompleted ? 1.5 : (isAdded ? 1.2 : 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          topRow,
          // Fields become non-interactive once completed — إعادة الفتح
          // (in [topRow], deliberately kept outside this ignore-pointer
          // scope) is the one way back in. Delete similarly lives in the
          // top row and stays reachable regardless of completion state (a
          // completed field-added record can still be deleted, per
          // `DetailScreen`'s own `onDelete` gating).
          isCompleted ? IgnorePointer(child: body) : body,
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

  Future<void> _editCropType(final BuildContext context) async {
    final ChoiceDialogResult<String>? result = await pickCropType(
      context,
      selected: parcel.cropType,
    );
    if (result == null) return;
    onFieldChanged(
      parcel.copyWith(cropType: result.isClear ? null : result.value),
    );
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

  Future<void> _editBasin(final BuildContext context) async {
    final List<String> basins = getIt<HoldingsRepository>().availableBasins;
    if (basins.isEmpty) {
      await _editText(
        context,
        title: 'holdings.fields.basin_name'.tr(),
        initialValue: parcel.basinName ?? '',
        apply: (final String v) =>
            parcel.copyWith(basinName: v.isEmpty ? null : v),
      );
      return;
    }

    final BasinPickResult? result = await pickBasin(
      context,
      selected: parcel.basinName,
    );
    if (result == null) return;
    onFieldChanged(applyBasinPick(parcel, result));
  }

  Future<void> _openBorderPerson(
    final BuildContext context,
    final String? borderText,
  ) async {
    final Parcel? match = resolveBorderMatch?.call(borderText);
    if (match == null) {
      context.showSnackBar('holdings.detail.border_no_data'.tr());
      return;
    }

    final List<Parcel> holdingParcels =
        getIt<HoldingsRepository>().parcelsForHolding(match.groupKey);
    await context.pushNamed(
      Routes.holdingDetail,
      arguments: holdingParcels,
    );
  }

  /// Copy ID is the field-worker completion action, and now the *only* one
  /// (`REFACTOR_ROADMAP.md` Phase 7, migrated to `completed_at`/
  /// `completed_by` in Phase 9 #12, standalone Finish button removed in
  /// Phase 9 #3): validates required fields, copies the id, then marks the
  /// parcel completed via `setParcelCompleted` — unless it's already
  /// completed, in which case this is a plain re-copy
  /// (re-marking an already-completed parcel via Copy ID would be a
  /// surprising side effect of an action the user takes repeatedly while
  /// working, e.g. to paste the id elsewhere after completion).
  ///
  /// Reflects the result via [onCompleted], never [onFieldChanged] —
  /// [onFieldChanged] routes to `DetailScreen._updateField`, which issues
  /// its own separate `updateParcel` (edit-overlay) write that doesn't
  /// carry `completedAt` at all.
  Future<void> _copyId(final BuildContext context) async {
    final bool isCompleted = parcel.completedAt != null;
    if (!isNew && !isCompleted && !parcel.hasRequiredFieldsFilled) {
      final List<String> gaps = requiredFieldGapMessages(parcel);
      context.showErrorSnackBar(gaps.first);
      return;
    }

    await Clipboard.setData(ClipboardData(text: parcel.id));
    if (!context.mounted) return;
    HapticFeedback.mediumImpact();

    if (isNew || isCompleted) {
      context.showSuccessSnackBar('holdings.detail.copied'.tr());
      return;
    }

    try {
      final Parcel? updated = await getIt<HoldingsRepository>()
          .setParcelCompleted(parcel.id, completed: true);
      if (!context.mounted) return;
      final Parcel confirmed =
          updated ?? parcel.copyWith(completedAt: DateTime.now());
      (onCompleted ?? onFieldChanged)(confirmed);
      context.showSuccessSnackBar('holdings.detail.copied_and_reviewed'.tr());
    } catch (error) {
      if (context.mounted) {
        context.showErrorSnackBar(
          resolveWriteErrorMessage(
            error,
            fallback: 'holdings.detail.copy_and_review_failed'.tr(),
          ),
        );
      }
    }
  }

  Future<void> _copyAll(final BuildContext context) async {
    final bool cropTypeRequired =
        UsageType.fromLabel(parcel.usageType) == UsageType.agricultural;
    if (cropTypeRequired && !Parcel.isValueFilled(parcel.cropType)) {
      context
          .showErrorSnackBar('holdings.detail.crop_type_required_to_copy'.tr());
      return;
    }
    // المساحة must be a real, non-zero value — a saved 0 (or nothing
    // entered at all) is indistinguishable otherwise, and copying it out
    // would silently hand a field worker a record that reads as "no land"
    // instead of "not yet surveyed" (`Parcel.isAreaFilled`'s own doc).
    if (!Parcel.isAreaFilled(
      feddan: parcel.feddan,
      qirat: parcel.qirat,
      sahm: parcel.sahm,
    )) {
      context.showErrorSnackBar('holdings.detail.area_required_to_copy'.tr());
      return;
    }

    final String text = _formatter.format(
      parcel,
      hideCreditType: hideCreditType,
      associationType: associationType,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      HapticFeedback.mediumImpact();
      context.showSuccessSnackBar('holdings.detail.copied'.tr());
    }
  }

  Future<void> _confirmDelete(final BuildContext context) async {
    await AppDialogs.showConfirm(
      context,
      message: 'holdings.detail.delete_confirm'.tr(),
      confirmText: 'holdings.detail.delete'.tr(),
      onConfirm: onDelete!,
    );
  }
}

/// The single "added" badge — the app no longer has a server-side profile
/// table to resolve [Parcel.createdBy] against, so this shows the badge
/// without a creator line.
class _AddedByBanner extends StatelessWidget {
  const _AddedByBanner({required this.parcel});

  final Parcel parcel;

  @override
  Widget build(final BuildContext context) {
    return ParcelDetailInfoBanner(
      icon: Icons.add_box_rounded,
      label: 'holdings.detail.added_badge'.tr(),
      subtitle: 'holdings.detail.added_badge_hint'.tr(),
      color: AppColors.blue200,
      creatorLine: null,
    );
  }
}

class _ReviewIdChip extends StatefulWidget {
  const _ReviewIdChip({
    required this.id,
    required this.onCopy,
    this.onBusyChanged,
  });

  final String id;

  /// `ParcelDetailCard._copyId` — already handles its own snackbars/error
  /// classification; this wrapper only needs to know when it starts/ends.
  final Future<void> Function(BuildContext context) onCopy;

  /// See `ParcelDetailCard.onReviewBusyChanged` — forwarded straight
  /// through, called around the same window as [_isLoading] below.
  final void Function(bool isBusy)? onBusyChanged;

  @override
  State<_ReviewIdChip> createState() => _ReviewIdChipState();
}

class _ReviewIdChipState extends State<_ReviewIdChip> {
  bool _isLoading = false;

  Future<void> _handleTap(final BuildContext context) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    widget.onBusyChanged?.call(true);
    try {
      await widget.onCopy(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
      widget.onBusyChanged?.call(false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    return ParcelIdChip(
      id: widget.id,
      isLoading: _isLoading,
      onCopy: () => _handleTap(context),
    );
  }
}
