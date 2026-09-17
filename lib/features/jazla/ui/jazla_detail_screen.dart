import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../core/router/routes.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/ui/dialogs/app_dialogs.dart';
import '../../holdings/data/model/parcel.dart';
import '../../holdings/data/repo/holdings_reader.dart';
import '../../holdings/data/repo/holdings_repository.dart';
import '../../holdings/ui/add_record_screen.dart';
import '../data/local/jazla_search_service.dart';
import '../data/repo/jazla_repo.dart';
import '../logic/cubit/jazla_add_parcel_cubit.dart';
import '../logic/cubit/jazla_add_parcel_state.dart';
import '../logic/cubit/jazla_detail_cubit.dart';
import '../logic/cubit/jazla_detail_state.dart';

import 'widgets/jazla_bulk_apply_sheet.dart';
import 'widgets/jazla_export_button.dart';
import 'widgets/jazla_parcel_result_tile.dart';
import 'widgets/jazla_parcel_tile.dart';
import 'widgets/jazla_quick_view_sheet.dart';
import 'widgets/jazla_search_bar.dart';

/// One Jazla's home screen — two tabs sharing the same `JazlaDetailCubit`
/// instance (so both "القطع الموجودة" and "إضافة قطعة" always see the same,
/// current parcel list without a page navigation between them):
/// - "القطع الموجودة": ordered, drag-reorderable list; tap opens the real,
///   unchanged holding [Routes.holdingDetail] screen; long-press offers
///   removal from this Jazla only (never touches the underlying parcel).
/// - "إضافة قطعة": always-visible search (no bottom sheet, so the keyboard
///   never covers it) using the same [JazlaSearchService] scoring as the
///   home search, at parcel level. A free result's "+" opens the compact
///   Quick View sheet; confirming there switches back to the first tab
///   with the new parcel already visible.
class JazlaDetailScreen extends StatelessWidget {
  const JazlaDetailScreen({super.key, required this.jazlaId});

  final String jazlaId;

  @override
  Widget build(final BuildContext context) {
    final String cityId = getIt<HoldingsRepository>().activeCityId ?? '';
    return MultiBlocProvider(
      providers: [
        BlocProvider<JazlaDetailCubit>(
          create: (final _) => JazlaDetailCubit(
            getIt<JazlaRepo>(),
            getIt<HoldingsReader>(),
            jazlaId,
            cityId,
          )..load(),
        ),
        BlocProvider<JazlaAddParcelCubit>(
          create: (final _) => JazlaAddParcelCubit(
            getIt<JazlaRepo>(),
            getIt<HoldingsReader>(),
            getIt<JazlaSearchService>(),
            jazlaId,
            cityId,
          ),
        ),
      ],
      child: const _JazlaDetailView(),
    );
  }
}

class _JazlaDetailView extends StatefulWidget {
  const _JazlaDetailView();

  @override
  State<_JazlaDetailView> createState() => _JazlaDetailViewState();
}

class _JazlaDetailViewState extends State<_JazlaDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _goToParcelsTab() => _tabController.animateTo(0);

  void _openParcelDetail(final BuildContext context, final Parcel parcel) {
    final List<Parcel> group =
        getIt<HoldingsRepository>().parcelsForHolding(parcel.groupKey);
    context.pushNamed(Routes.holdingDetail, arguments: group);
  }

  Future<void> _confirmRemove(
    final BuildContext context,
    final JazlaDetailCubit cubit,
    final Parcel parcel,
  ) async {
    await AppDialogs.showConfirm(
      context,
      title: 'jazla.detail.remove_confirm_title'.tr(),
      message: 'jazla.detail.remove_confirm_message'.tr(),
      confirmText: 'jazla.detail.remove'.tr(),
      onConfirm: () {
        Navigator.pop(context);
        cubit.removeParcel(parcel.id);
      },
    );
  }

  Future<void> _openQuickView(final Parcel parcel, final String jazlaId) async {
    final bool? added = await showJazlaQuickViewSheet(
      context,
      parcel: parcel,
      jazlaId: jazlaId,
    );
    if (added == true && mounted) {
      // The underlying parcel/Jazla data changed via a different cubit
      // (Quick View writes through `HoldingsWriter`/`JazlaRepo` directly) —
      // reload this screen's own `JazlaDetailCubit` instance so Tab 1
      // reflects the addition immediately, then switch to it.
      context.read<JazlaDetailCubit>().load();
      _goToParcelsTab();
    }
  }

  Future<void> _addNewPerson(final String jazlaId) async {
    final JazlaAddParcelCubit addCubit = context.read<JazlaAddParcelCubit>();
    final Parcel? created = await context.pushNamed<Parcel>(
      Routes.addRecord,
      arguments: const AddRecordArgs(
        initialParcel: Parcel(holdingId: '', landNumber: '0', holdingsCount: 1),
      ),
    );
    if (created == null || !mounted) return;
    await addCubit.onExternalParcelCreated(created);
    if (mounted) {
      context.read<JazlaDetailCubit>().load();
      _goToParcelsTab();
    }
  }

  Future<void> _openBulkApply(final String jazlaId, final List<Parcel> parcels) async {
    await showJazlaBulkApplySheet(context, jazlaId: jazlaId, parcels: parcels);
    if (mounted) context.read<JazlaDetailCubit>().load();
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      backgroundColor: colors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: BlocBuilder<JazlaDetailCubit, JazlaDetailState>(
          builder: (final BuildContext context, final JazlaDetailState state) {
            if (state.status == JazlaDetailStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == JazlaDetailStatus.notFound || state.jazla == null) {
              return Column(
                children: [
                  ScreenHeader(title: 'jazla.title'.tr()),
                  const Expanded(child: Center(child: Text('—'))),
                ],
              );
            }

            final String jazlaId = state.jazla!.id;
            final List<Parcel> parcels = state.parcels;
            final JazlaDetailCubit cubit = context.read<JazlaDetailCubit>();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: rw(4)),
                  child: Row(
                    children: [
                      Expanded(
                        child: ScreenHeader(title: state.jazla!.name),
                      ),
                      IconButton(
                        icon: const Icon(Icons.bolt_rounded, color: AppColors.amber200),
                        tooltip: 'jazla.detail.bulk_apply'.tr(),
                        onPressed: parcels.isEmpty
                            ? null
                            : () => _openBulkApply(jazlaId, parcels),
                      ),
                      JazlaExportButton(jazlaName: state.jazla!.name, parcels: parcels),
                      horizontalSpacing(8),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: rw(16)),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary200,
                    unselectedLabelColor: colors.textSecondary,
                    indicatorColor: AppColors.primary200,
                    labelStyle: AppTextStyles.font14SemiBold,
                    tabs: [
                      Tab(text: 'jazla.detail.tab_parcels'.tr()),
                      Tab(text: 'jazla.detail.tab_add'.tr()),
                    ],
                  ),
                ),
                verticalSpacing(8),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _ParcelsTab(
                        parcels: parcels,
                        onReorder: cubit.reorder,
                        onTapParcel: (final Parcel p) => _openParcelDetail(context, p),
                        onLongPressParcel: (final Parcel p) =>
                            _confirmRemove(context, cubit, p),
                      ),
                      _AddParcelTab(
                        searchController: _searchController,
                        onAddTap: (final Parcel p) => _openQuickView(p, jazlaId),
                        onAddNewPerson: () => _addNewPerson(jazlaId),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ParcelsTab extends StatelessWidget {
  const _ParcelsTab({
    required this.parcels,
    required this.onReorder,
    required this.onTapParcel,
    required this.onLongPressParcel,
  });

  final List<Parcel> parcels;
  final void Function(List<String> newOrderIds) onReorder;
  final void Function(Parcel parcel) onTapParcel;
  final void Function(Parcel parcel) onLongPressParcel;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    if (parcels.isEmpty) {
      return Center(
        child: Text(
          'jazla.detail.empty'.tr(),
          style: TextStyle(color: colors.textSecondary),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(rw(16), 0, rw(16), rh(24)),
      itemCount: parcels.length,
      onReorder: (final int oldIndex, int newIndex) {
        if (newIndex > oldIndex) newIndex -= 1;
        final List<String> ids = parcels.map((final Parcel p) => p.id).toList();
        final String moved = ids.removeAt(oldIndex);
        ids.insert(newIndex, moved);
        onReorder(ids);
      },
      itemBuilder: (final BuildContext context, final int i) {
        final Parcel parcel = parcels[i];
        return Padding(
          key: ValueKey<String>(parcel.id),
          padding: const EdgeInsets.only(bottom: 10),
          child: JazlaParcelTile(
            index: i + 1,
            parcel: parcel,
            onTap: () => onTapParcel(parcel),
            onLongPress: () => onLongPressParcel(parcel),
          ),
        );
      },
    );
  }
}

class _AddParcelTab extends StatelessWidget {
  const _AddParcelTab({
    required this.searchController,
    required this.onAddTap,
    required this.onAddNewPerson,
  });

  final TextEditingController searchController;
  final ValueChanged<Parcel> onAddTap;
  final VoidCallback onAddNewPerson;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: rw(16)),
          child: JazlaSearchBar(
            controller: searchController,
            onChanged: (final String q) =>
                context.read<JazlaAddParcelCubit>().search(q),
          ),
        ),
        verticalSpacing(12),
        Expanded(
          child: BlocBuilder<JazlaAddParcelCubit, JazlaAddParcelState>(
            builder: (final BuildContext context, final JazlaAddParcelState state) {
              if (state.query.trim().isEmpty) {
                return const SizedBox.shrink();
              }
              if (state.results.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: rh(24)),
                  child: Column(
                    children: [
                      Text(
                        'jazla.add_sheet.no_results'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      verticalSpacing(12),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: rw(16)),
                        child: OutlinedButton.icon(
                          onPressed: onAddNewPerson,
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                          label: Text(
                            'jazla.add_sheet.add_new_person'.tr(),
                            style: AppTextStyles.font14SemiBold
                                .copyWith(color: AppColors.primary200),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: rw(16)),
                itemCount: state.results.length,
                itemBuilder: (final BuildContext context, final int i) {
                  final ParcelSearchResult result = state.results[i];
                  return JazlaParcelResultTile(
                    result: result,
                    onAddTap: () => onAddTap(result.parcel),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(rw(16), 0, rw(16), rh(16)),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddNewPerson,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text(
                    'jazla.add_sheet.add_new_person'.tr(),
                    style: AppTextStyles.font14SemiBold.copyWith(color: AppColors.primary200),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
