import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../data/repo/holdings_repository.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/errors/error_message_resolver.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/ui/loaders/blocking_loading_overlay.dart';
import '../data/model/parcel.dart';
import 'add_record_screen.dart';
import 'widgets/detail_screen_header.dart';
import 'widgets/parcel_detail_card.dart';
import 'widgets/parcel_status_filter.dart';

/// Full record for one holding. If the holding has multiple parcels they
/// are all stacked in one scrollable view, each with its own compass and
/// fields (per the chosen UX — no per-parcel sub-routing).
class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.parcels});

  final List<Parcel> parcels;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen>
    with SingleTickerProviderStateMixin {
  final HoldingsRepository _repository = getIt<HoldingsRepository>();
  late List<Parcel> _parcels;

  /// The identifying [Parcel.groupKey] shared by every parcel on this
  /// screen — captured once at [initState] so [_refreshFromRepository] and
  /// [_remoteChangesSub] can always re-derive the current, complete set of
  /// this person's parcels from the repository (the source of truth),
  /// rather than growing/patching [_parcels] by hand at each call site.
  /// Every parcel passed into this screen shares one groupKey by
  /// construction (`HomeScreen._openDetail` builds the list via
  /// `parcelsForHolding(result.groupKey)`), so reading the first entry's is
  /// safe even for the (rare) empty-list case elsewhere in this file.
  String? _groupKey;

  /// Guards each write action against a concurrent second tap on the *same*
  /// parcel while its own request is in flight, and drives the delete/
  /// reopen spinners on that parcel's card (`REFACTOR_ROADMAP.md` Phase 21
  /// — previously a single screen-wide `bool` with no visible feedback at
  /// all). Keyed by parcel id rather than a single flag since several cards
  /// are on screen at once and each needs its own independent busy state —
  /// deleting one parcel must not block reopening a different one.
  final Set<String> _busyParcelIds = <String>{};

  bool _isParcelBusy(final String parcelId) =>
      _busyParcelIds.contains(parcelId);

  /// Folds `ParcelDetailCard`'s Copy ID busy window into [_busyParcelIds] —
  /// see `ParcelDetailCard.onReviewBusyChanged`'s doc. Deliberately does NOT
  /// set [_busyMessage]/the screen-wide overlay the way delete/reopen/edit
  /// do: Copy ID already has its own local spinner via `_ReviewIdChip`, and
  /// this screen only needs to know the window exists so it can disable
  /// this same parcel's Reopen/Delete for its duration — not to duplicate
  /// the loading UI itself.
  void _setReviewBusy(final String parcelId, final bool isBusy) {
    if (!mounted) return;
    setState(() {
      if (isBusy) {
        _busyParcelIds.add(parcelId);
      } else {
        _busyParcelIds.remove(parcelId);
      }
    });
  }

  /// Drives the screen-wide [BlockingLoadingOverlay] while any write is in
  /// flight — set to the action-specific message right before the awaited
  /// repository call and cleared in every `finally`, so the message on
  /// screen always matches the action actually running.
  String? _busyMessage;

  /// Exactly three tabs — الكل/المضافة/تمت المراجعة (`REFACTOR_ROADMAP.md`
  /// Phase 11 §11), always shown (unlike the filter-chip row this replaced,
  /// which only appeared for holdings with more than one parcel). الكل is
  /// always the default/opening tab, per the spec.
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: DetailScreenTab.values.length, vsync: this)
          ..addListener(() {
            if (!_tabController.indexIsChanging) setState(() {});
          });
    _parcels = List<Parcel>.of(widget.parcels);
    _groupKey = _parcels.isEmpty ? null : _parcels.first.groupKey;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Re-reads every parcel sharing [_groupKey] from the repository — the
  /// single source of truth — and reflects it on screen. Called after every
  /// successful write this screen makes (so the new/changed state is
  /// visible immediately, without requiring the user to leave and return)
  /// and on every incoming Realtime event.
  ///
  /// A remote change this screen didn't cause (e.g. another parcel entirely
  /// being reconciled/promoted elsewhere, which still fires the same shared
  /// `onRemoteChange` stream) can occasionally follow a captured [_groupKey]
  /// that's gone stale in ways this screen has no direct way to detect —
  /// falls back to re-deriving it from any currently-shown parcel's own
  /// (possibly now-different) `groupKey` before giving up and showing an
  /// empty list, so a spurious unrelated notification never blanks a
  /// holding that's still genuinely there.
  void _refreshFromRepository() {
    final String? groupKey = _groupKey;
    if (groupKey == null || !mounted) return;
    List<Parcel> result = _repository.parcelsForHolding(groupKey);
    if (result.isEmpty && _parcels.isNotEmpty) {
      debugPrint(
        '[DetailScreen] _refreshFromRepository: groupKey=$groupKey '
        'returned 0 parcels but screen previously showed '
        '${_parcels.length} — attempting to re-derive groupKey from a '
        'currently-known parcel id instead of showing empty.',
      );
      for (final Parcel p in _parcels) {
        final Parcel? fresh = _repository.parcels
            .cast<Parcel?>()
            .firstWhere((final Parcel? c) => c?.id == p.id, orElse: () => null);
        if (fresh == null) continue;
        final List<Parcel> retry =
            _repository.parcelsForHolding(fresh.groupKey);
        debugPrint(
          '[DetailScreen] tried parcel id=${p.id}, current groupKey='
          '${fresh.groupKey} (was ${p.groupKey}) → ${retry.length} results',
        );
        if (retry.isNotEmpty) {
          _groupKey = fresh.groupKey;
          result = retry;
          break;
        }
      }
    }
    setState(() {
      _parcels = result;
    });
  }

  Future<void> _deleteParcel(final Parcel parcel) async {
    if (_isParcelBusy(parcel.id)) return;
    setState(() {
      _busyParcelIds.add(parcel.id);
      _busyMessage = 'holdings.detail.deleting_in_progress'.tr();
    });
    try {
      final bool deleted = await _repository.deleteLocalParcel(parcel.id);
      if (!mounted) return;
      if (!deleted) {
        context.showErrorSnackBar('holdings.detail.delete_failed'.tr());
        return;
      }
      setState(() {
        _parcels =
            _parcels.where((final Parcel p) => p.id != parcel.id).toList();
      });
      context.showSuccessSnackBar('holdings.detail.deleted'.tr());
    } catch (error) {
      if (mounted) {
        context.showErrorSnackBar(
          resolveWriteErrorMessage(
            error,
            fallback: 'holdings.detail.delete_error'.tr(),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyParcelIds.remove(parcel.id);
          _busyMessage = null;
        });
      }
    }
  }

  /// Un-marks [parcel] completed — user-initiated, no confirmation dialog,
  /// no snackbar (decision #2: deliberate user-initiated undo).
  Future<void> _reopenParcel(final Parcel parcel) async {
    if (_isParcelBusy(parcel.id)) return;
    setState(() {
      _busyParcelIds.add(parcel.id);
      _busyMessage = 'holdings.detail.reopening_in_progress'.tr();
    });
    try {
      final Parcel? updated =
          await _repository.setParcelCompleted(parcel.id, completed: false);
      if (!mounted) return;
      final int idx =
          _parcels.indexWhere((final Parcel p) => p.id == parcel.id);
      if (idx >= 0) {
        setState(() {
          _parcels[idx] = updated ?? _parcels[idx].copyWith(completedAt: null);
        });
      }
    } catch (error) {
      if (mounted) {
        context.showErrorSnackBar(
          resolveWriteErrorMessage(
            error,
            fallback: 'holdings.detail.reopen_failed'.tr(),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyParcelIds.remove(parcel.id);
          _busyMessage = null;
        });
      }
    }
  }

  /// Reflects a `ParcelDetailCard._copyId`-confirmed review into local state
  /// (`REFACTOR_ROADMAP.md` Phase 20) — deliberately just `setState`, no
  /// repository call. By the time this fires, `setParcelCompleted` has
  /// already been awaited and server-confirmed inside the card; issuing a
  /// second write here (the old `onFieldChanged`/`_updateField` path) would
  /// be redundant at best and, if it failed for an unrelated reason, could
  /// mask an already-successful review behind a "save failed" message.
  void _onParcelCompleted(final Parcel updated) {
    if (!mounted) return;
    final int idx = _parcels.indexWhere((final Parcel p) => p.id == updated.id);
    if (idx >= 0) setState(() => _parcels[idx] = updated);
  }

  /// الملاحظات default used when a brand-new parcel is created (Add Parcel/
  /// Add Person) — still freely user-editable in the form before saving.
  static const String _needsSurveyNote = 'نقص بيانات الحصر';

  /// الملاحظات value automatically set when نوع الاستخدام is changed away
  /// from the default زراعة (`REFACTOR_ROADMAP.md` Phase 12).
  static const String _nonAgriculturalUsageNote = 'استخدام غير زراعي';

  /// الملاحظات no longer gets force-overwritten on every field edit — that
  /// silently discarded whatever the user had actually written whenever
  /// they corrected any unrelated field (`REFACTOR_ROADMAP.md` Phase 12).
  /// It's now only auto-set by two specific, deliberate triggers:
  /// - المساحة (فدان/قيراط/سهم or المساحة بالمتر) changing → "نقص بيانات
  ///   الحصر" (the field survey for this parcel needs re-verifying).
  /// - نوع الاستخدام changing away from the زراعة default → "استخدام غير
  ///   زراعي".
  /// Every other field edit leaves الملاحظات exactly as the user last set
  /// it. If both triggers fire in the same edit, نوع الاستخدام's message
  /// wins (it's the more specific, actionable one).
  Future<void> _updateField(final Parcel updated) async {
    if (_isParcelBusy(updated.id)) return;
    setState(() {
      _busyParcelIds.add(updated.id);
      _busyMessage = 'holdings.detail.saving_field'.tr();
    });
    try {
      final int idx = _parcels.indexWhere(
        (final Parcel p) => p.id == updated.id,
      );
      final Parcel? before = idx >= 0 ? _parcels[idx] : null;
      Parcel toSave = updated;
      if (before != null) {
        final bool areaChanged = updated.feddan != before.feddan ||
            updated.qirat != before.qirat ||
            updated.sahm != before.sahm ||
            updated.totalSqm != before.totalSqm;
        final bool usageChangedAwayFromDefault =
            updated.usageType != before.usageType &&
                updated.usageType != Parcel.defaultUsageType;
        if (areaChanged) {
          toSave = toSave.copyWith(notes: _needsSurveyNote);
        }
        if (usageChangedAwayFromDefault) {
          toSave = toSave.copyWith(notes: _nonAgriculturalUsageNote);
        }
      }

      await _repository.updateParcel(toSave);
      if (idx >= 0) {
        setState(() => _parcels[idx] = toSave);
      }
      if (mounted) context.showSuccessSnackBar('holdings.edit.saved'.tr());
    } catch (error) {
      if (mounted) {
        context.showErrorSnackBar(
          resolveWriteErrorMessage(
            error,
            fallback: 'holdings.detail.save_failed'.tr(),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyParcelIds.remove(updated.id);
          _busyMessage = null;
        });
      }
    }
  }

  /// Pre-fills a new-parcel form from [source] per APP_PLAN.md decision
  /// #8: everything copied except المساحة (blanked — entered fresh for
  /// the new land), رقم الأرض (defaults to `-1`, must be corrected), and
  /// اسم الحوض (blanked — required fields must always be actively chosen
  /// by the user, even for a parcel added under an existing person whose
  /// other parcels already have one).
  Future<void> _addParcelForPerson(final Parcel source) async {
    final Parcel template = source.copyWith(
      landNumber: '-1',
      feddan: null,
      qirat: null,
      sahm: null,
      totalSqm: null,
      basinName: null,
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
    if (added != true || !mounted) return;
    // The new parcel already exists in the repository (addLocalParcel only
    // returns after the server confirms the write) — re-reading by
    // groupKey here is what makes it appear on this screen immediately,
    // without requiring the user to leave and come back. Previously this
    // only showed a success snackbar and never touched `_parcels`, so the
    // screen looked unchanged; a user who (reasonably) assumed the add had
    // failed and left without noticing would find the correctly-grouped
    // person already showing 2 parcels in search — easy to misread as "the
    // new parcel became a separate person" when it was actually this
    // screen simply never having displayed it in the first place.
    _refreshFromRepository();
    context.showSuccessSnackBar('holdings.add.saved'.tr());
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String holdingId =
        _parcels.isNotEmpty ? _parcels.first.holdingId : '';
    final DetailScreenTab activeTab =
        DetailScreenTab.values[_tabController.index];
    // Deliberately NOT re-sorted by completion state — a parcel keeps its
    // original position after being reviewed/reopened instead of jumping
    // elsewhere in the list, so it stays easy to visually track. Combined
    // with the ValueKey below, this is what stops the card from tearing
    // down and re-playing its entrance animation on a state-only update.
    final List<Parcel> visibleParcels =
        _parcels.where((final Parcel p) => activeTab.matches(p)).toList();

    final bool showAddFab = _parcels.isNotEmpty;

    return PopScope(
      canPop: _busyMessage == null,
      child: BlockingLoadingOverlay(
        visible: _busyMessage != null,
        message: _busyMessage,
        child: Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: Stack(
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DetailScreenHeader(
                      holdingId: holdingId,
                      parcelCount: _parcels.length,
                    ),
                    // Exactly three tabs, always shown (`REFACTOR_ROADMAP.md`
                    // Phase 11 §11) — unlike the filter-chip row this replaced,
                    // which only appeared once a holding had more than one
                    // parcel; a fixed tab bar is part of the screen's layout
                    // regardless of how many parcels are on it.
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary200,
                      unselectedLabelColor: colors.textSecondary,
                      indicatorColor: AppColors.primary200,
                      tabs: [
                        for (final DetailScreenTab tab
                            in DetailScreenTab.values)
                          Tab(text: tab.label()),
                      ],
                    ),
                    verticalSpacing(8),
                    Expanded(
                      child: visibleParcels.isEmpty
                          ? Center(
                              child: Text(
                                'holdings.detail.empty'.tr(),
                                style: AppTextStyles.font16Regular.copyWith(
                                  color: colors.textHint,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: rw(16),
                              ).copyWith(
                                  bottom: rh(16 + (showAddFab ? 64 : 0))),
                              itemCount: visibleParcels.length,
                              itemBuilder:
                                  (final BuildContext context, final int i) {
                                final Parcel parcel = visibleParcels[i];
                                return Padding(
                                  key: ValueKey<String>(parcel.id),
                                  padding: EdgeInsets.only(bottom: rh(16)),
                                  child: ParcelDetailCard(
                                    parcel: parcel,
                                    originalParcel:
                                        _repository.originalParcel(parcel.id),
                                    // "New / unsynced" no longer applies once
                                    // every write is confirmed-or-failed
                                    // synchronously — there is no more window
                                    // where a record is visible but not yet on
                                    // the server.
                                    isNew: false,
                                    hideCreditType: _repository.hideCreditType,
                                    associationType:
                                        _repository.activeAssociationType,
                                    onFieldChanged: _updateField,
                                    onCompleted: _onParcelCompleted,
                                    animationDelay:
                                        Duration(milliseconds: i * 80),
                                    resolveBorderMatch:
                                        _repository.findByBorderText,
                                    onDelete:
                                        parcel.sourceAddedHoldingId != null &&
                                                parcel.completedAt == null
                                            ? () => _deleteParcel(parcel)
                                            : null,
                                    onReopen: () => _reopenParcel(parcel),
                                    isDeleting: _isParcelBusy(parcel.id),
                                    isReopening: _isParcelBusy(parcel.id),
                                    onReviewBusyChanged: (final bool isBusy) =>
                                        _setReviewBusy(parcel.id, isBusy),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
                if (showAddFab)
                  PositionedDirectional(
                    bottom: rh(20),
                    end: rw(20),
                    child: FloatingActionButton.extended(
                      onPressed: () => _addParcelForPerson(_parcels.first),
                      icon: const Icon(Icons.add_location_alt_rounded),
                      label: Text('holdings.add.new_parcel_title'.tr()),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
