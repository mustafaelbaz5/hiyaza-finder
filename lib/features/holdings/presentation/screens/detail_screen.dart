import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../hiyaza_finder_app.dart';
import '../../data/repository/holdings_repository.dart';
import '../../domain/entities/parcel.dart';
import '../widgets/detail_screen_header.dart';
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

class _DetailScreenState extends State<DetailScreen> with WidgetsBindingObserver {
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

  /// Guards each write action against a concurrent second tap while its own
  /// request is in flight — a single flag is enough since this screen's
  /// actions (delete/finish/reopen/field-edit) are never meant to run two
  /// at once. Drives no visible spinner of its own (the per-card widgets
  /// already show their own tap-affordance state); it exists purely to
  /// reject a re-entrant call while the first is still awaiting Supabase.
  bool _isBusy = false;

  late final StreamSubscription<void> _remoteChangesSub;

  @override
  void initState() {
    super.initState();
    _parcels = List<Parcel>.of(widget.parcels);
    _groupKey = _parcels.isEmpty ? null : _parcels.first.groupKey;
    // A Realtime event (e.g. this exact person's newly-added parcel being
    // promoted server-side, or an edit from another device) mutates
    // `HoldingsRepository`'s own list directly — without this subscription
    // this screen would only reflect such a change on its own successful
    // writes, never on one that originated elsewhere while this screen is
    // already open.
    _remoteChangesSub = _repository.onRemoteChange
        .listen((final _) => _refreshFromRepository());
    WidgetsBinding.instance.addObserver(this);
  }

  /// The manual refresh icon/pull-gesture on this screen is deliberately
  /// gone too (`REFACTOR_ROADMAP.md` Phase 9 #8) — same rationale as
  /// `HomeScreen`. `syncNow()` (not just re-reading the repository) is
  /// needed here specifically because `loadParcelsForCity`/`adopt` doesn't
  /// fire `onRemoteChange` — a resume-triggered resync from `HomeScreen`
  /// alone would silently miss updating an already-open `DetailScreen`.
  @override
  void didChangeAppLifecycleState(final AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        _repository.syncNow().then((final _) {
          if (mounted) _refreshFromRepository();
        }).catchError((final _) {}),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _remoteChangesSub.cancel();
    super.dispose();
  }

  /// Re-reads every parcel sharing [_groupKey] from the repository — the
  /// single source of truth — and reflects it on screen. Called after every
  /// successful write this screen makes (so the new/changed state is
  /// visible immediately, without requiring the user to leave and return)
  /// and on every incoming Realtime event.
  void _refreshFromRepository() {
    final String? groupKey = _groupKey;
    if (groupKey == null || !mounted) return;
    setState(() {
      _parcels = _repository.parcelsForHolding(groupKey);
    });
  }

  Future<void> _deleteParcel(final Parcel parcel) async {
    if (_isBusy) return;
    _isBusy = true;
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
    } catch (_) {
      if (mounted) context.showErrorSnackBar('errors.unknown'.tr());
    } finally {
      _isBusy = false;
    }
  }

  /// Marks [parcel] completed (the field-worker signal — `SYSTEM_DESIGN.md`
  /// §10, `REFACTOR_ROADMAP.md` Phase 9 #12), shows a 5s undo snackbar via
  /// the app-level `scaffoldMessengerKey` (so it survives this screen
  /// popping — see `HiyazaFinderApp.scaffoldMessengerKey`), and pops back
  /// to search immediately per the requirement that Finish returns to
  /// search.
  Future<void> _finishParcel(final Parcel parcel) async {
    if (_isBusy) return;
    _isBusy = true;
    try {
      await _repository.setParcelCompleted(parcel.id, completed: true);
    } catch (_) {
      _isBusy = false;
      if (mounted) context.showErrorSnackBar('errors.unknown'.tr());
      return;
    }
    _isBusy = false;
    if (!mounted) return;
    final int idx = _parcels.indexWhere((final Parcel p) => p.id == parcel.id);
    if (idx >= 0) {
      setState(() {
        _parcels[idx] = _parcels[idx].copyWith(completedAt: DateTime.now());
      });
    }

    HiyazaFinderApp.scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('holdings.detail.finished'.tr()),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'holdings.detail.undo'.tr(),
          // May fire after this screen has been popped — must not touch
          // this.context/setState, only the repository (a GetIt singleton
          // independent of any screen's lifecycle) and the app-level
          // scaffold messenger key, both outliving this screen. A failed
          // undo surfaces its own snackbar via that same app-level key
          // rather than this.context, which may already be unmounted.
          // Search screen re-reads repository state on its own next
          // rebuild regardless of outcome.
          onPressed: () {
            _repository
                .setParcelCompleted(parcel.id, completed: false)
                .catchError(
              (final Object _) {
                HiyazaFinderApp.scaffoldMessengerKey.currentState?.showSnackBar(
                  SnackBar(content: Text('errors.unknown'.tr())),
                );
                return null;
              },
            );
          },
        ),
      ),
    );

    if (mounted) context.pop();
  }

  /// Un-marks [parcel] completed — user-initiated, no confirmation dialog,
  /// no snackbar (decision #2: deliberate user-initiated undo).
  Future<void> _reopenParcel(final Parcel parcel) async {
    if (_isBusy) return;
    _isBusy = true;
    try {
      await _repository.setParcelCompleted(parcel.id, completed: false);
      if (!mounted) return;
      final int idx =
          _parcels.indexWhere((final Parcel p) => p.id == parcel.id);
      if (idx >= 0) {
        setState(() {
          _parcels[idx] = _parcels[idx].copyWith(completedAt: null);
        });
      }
    } catch (_) {
      if (mounted) context.showErrorSnackBar('errors.unknown'.tr());
    } finally {
      _isBusy = false;
    }
  }

  /// Default الملاحظات value applied automatically whenever an existing
  /// record is edited or a new parcel is added for an existing person —
  /// flags the record as needing a field-survey follow-up without relying
  /// on the user to remember to set it themselves.
  static const String _needsSurveyNote = 'نقص بيانات الحصر';

  Future<void> _updateField(final Parcel updated) async {
    if (_isBusy) return;
    _isBusy = true;
    try {
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
    } catch (_) {
      if (mounted) context.showErrorSnackBar('errors.unknown'.tr());
    } finally {
      _isBusy = false;
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

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DetailScreenHeader(
              holdingId: holdingId,
              parcelCount: _parcels.length,
              onAddParcel: _parcels.isEmpty
                  ? null
                  : () => _addParcelForPerson(_parcels.first),
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
                  : ListView.builder(
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
                            animationDelay: Duration(milliseconds: i * 80),
                            resolveBorderMatch: _repository.findByBorderText,
                            onDelete: parcel.sourceAddedHoldingId != null &&
                                    parcel.completedAt == null
                                ? () => _deleteParcel(parcel)
                                : null,
                            onFinish: () => _finishParcel(parcel),
                            onReopen: () => _reopenParcel(parcel),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
