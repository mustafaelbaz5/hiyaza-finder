import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../domain/entities/parcel.dart';
import '../../data/repository/holdings_repository.dart';
import '../widgets/parcel_detail_card.dart';
import 'add_record_screen.dart';

/// Full record for one holding. If the holding has multiple parcels they
/// are all stacked in one scrollable view, each with its own compass and
/// fields (per the chosen UX — no per-parcel sub-routing).
class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.parcels});

  final List<Parcel> parcels;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final HoldingsRepository _repository = getIt<HoldingsRepository>();
  late List<Parcel> _parcels;

  /// Ids of the currently-shown parcels that are still-unsynced field-added
  /// records — the only ones deletable (see
  /// `HoldingsRepository.canDeleteLocalParcel`). Computed once per load
  /// (not per `build()`, since the underlying check reads the async sync
  /// outbox) and refreshed after any add/delete on this screen.
  Set<String> _deletableIds = <String>{};

  @override
  void initState() {
    super.initState();
    _parcels = List<Parcel>.of(widget.parcels);
    unawaited(_refreshDeletableIds());
  }

  Future<void> _refreshDeletableIds() async {
    final Set<String> deletable = <String>{};
    for (final Parcel p in _parcels) {
      if (await _repository.canDeleteLocalParcel(p.id)) deletable.add(p.id);
    }
    if (mounted) setState(() => _deletableIds = deletable);
  }

  Future<void> _deleteParcel(final Parcel parcel) async {
    final bool deleted = await _repository.deleteLocalParcel(parcel.id);
    if (!mounted) return;
    if (!deleted) {
      context.showErrorSnackBar('holdings.detail.delete_failed'.tr());
      return;
    }
    setState(() {
      _parcels = _parcels.where((final Parcel p) => p.id != parcel.id).toList();
      _deletableIds.remove(parcel.id);
    });
    context.showSuccessSnackBar('holdings.detail.deleted'.tr());
  }

  /// Default الملاحظات value applied automatically whenever an existing
  /// record is edited or a new parcel is added for an existing person —
  /// flags the record as needing a field-survey follow-up without relying
  /// on the user to remember to set it themselves.
  static const String _needsSurveyNote = 'نقص بيانات الحصر';

  Future<void> _updateField(final Parcel updated) async {
    final int idx = _parcels.indexWhere(
      (final Parcel p) => p.id == updated.id,
    );
    // Force الملاحظات to the "needs survey" default on every field edit —
    // unless this save is itself the user explicitly changing الملاحظات
    // (detected by comparing against the pre-edit value), in which case
    // their choice wins instead of being overwritten.
    final Parcel? before = idx >= 0 ? _parcels[idx] : null;
    final Parcel toSave = (before != null && updated.notes == before.notes)
        ? updated.copyWith(notes: _needsSurveyNote)
        : updated;

    await _repository.updateParcel(toSave);
    if (idx >= 0) {
      setState(() => _parcels[idx] = toSave);
    }
    if (mounted) context.showSuccessSnackBar('holdings.edit.saved'.tr());
  }

  /// Pre-fills a new-parcel form from [source] per APP_PLAN.md decision
  /// #8: everything copied except المساحة (blanked — entered fresh for
  /// the new land) and رقم الأرض (defaults to `-1`, must be corrected).
  Future<void> _addParcelForPerson(final Parcel source) async {
    final Parcel template = source.copyWith(
      landNumber: '-1',
      feddan: null,
      qirat: null,
      sahm: null,
      totalSqm: null,
      // عدد القطع في الحيازة grows by one for the new parcel being added.
      holdingsCount: (source.holdingsCount ?? 1) + 1,
      // Flags the new parcel as needing a field-survey follow-up, same as
      // an edit to an existing record — still user-editable in the form
      // before saving.
      notes: _needsSurveyNote,
    );
    final bool? added = await context.pushNamed<bool>(
      Routes.addRecord,
      arguments: AddRecordArgs(
        initialParcel: template,
        parentHoldingId: source.id,
      ),
    );
    if (added == true && mounted) {
      context.showSuccessSnackBar('holdings.add.saved'.tr());
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String holdingId =
        _parcels.isNotEmpty ? _parcels.first.holdingId : '';

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: rw(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  verticalSpacing(16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      const AppBackButton(),
                      horizontalSpacing(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              'holdings.detail.title'.tr(
                                namedArgs: {'id': holdingId},
                              ),
                              style: AppTextStyles.font20Bold.copyWith(
                                color: colors.textPrimary,
                              ),
                              textAlign: TextAlign.right,
                            ),
                            if (_parcels.length > 1) ...<Widget>[
                              verticalSpacing(2),
                              Text(
                                'holdings.detail.parcel_count'.tr(
                                  namedArgs: {
                                    'count': _parcels.length.toString(),
                                  },
                                ),
                                style: AppTextStyles.font12Regular.copyWith(
                                  color: colors.textSecondary,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_parcels.isNotEmpty) ...<Widget>[
                    verticalSpacing(12),
                    CustomTextButton.outlined(
                      text: 'holdings.add.new_parcel_title'.tr(),
                      size: CustomButtonSize.small,
                      isFullWidth: false,
                      prefixIcon: const Icon(Icons.add_location_alt_rounded),
                      onPressed: () => _addParcelForPerson(_parcels.first),
                    ),
                  ],
                  verticalSpacing(16),
                ],
              ),
            ),
            Expanded(
              child: _parcels.isEmpty
                  ? Center(
                      child: Text(
                        'holdings.detail.empty'.tr(),
                        style: AppTextStyles.font16Regular.copyWith(
                          color: colors.textHint,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _repository.syncNow(),
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: rw(16),
                        ).copyWith(bottom: rh(16)),
                        itemCount: _parcels.length,
                        itemBuilder: (final BuildContext context, final int i) {
                          final Parcel parcel = _parcels[i];
                          return Padding(
                            padding: EdgeInsets.only(bottom: rh(16)),
                            child: ParcelDetailCard(
                              parcel: parcel,
                              isEdited: _repository.isParcelEdited(parcel.id),
                              isNew: _repository.isNewLocalRecord(parcel.id),
                              hideCreditType: _repository.hideCreditType,
                              associationType:
                                  _repository.activeAssociationType,
                              onFieldChanged: _updateField,
                              animationDelay: Duration(milliseconds: i * 80),
                              resolveBorderMatch: _repository.findByBorderText,
                              onDelete: _deletableIds.contains(parcel.id)
                                  ? () => _deleteParcel(parcel)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
