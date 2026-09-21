import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hiyaza_finder/features/jazla/ui/widgets/add_parcel_tab.dart';
import 'package:hiyaza_finder/features/jazla/ui/widgets/parcels_tab.dart';

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
import '../../holdings/ui/widgets/basin_picker.dart';
import '../data/local/jazla_search_service.dart';
import '../data/model/jazla.dart';
import '../data/repo/jazla_repo.dart';
import '../logic/cubit/jazla_add_parcel_cubit.dart';
import '../logic/cubit/jazla_detail_cubit.dart';
import '../logic/cubit/jazla_detail_state.dart';
import 'widgets/jazla_bulk_apply_sheet.dart';
import 'widgets/jazla_export_button.dart';
import 'widgets/jazla_area_summary.dart';
import 'widgets/jazla_area_dialog.dart';
import 'widgets/jazla_pdf_share_button.dart';
import 'widgets/jazla_actions_sheet.dart';
import 'jazla_review_screen.dart';

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
  late final TabController _tabController =
      TabController(length: 2, vsync: this);
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _goToParcelsTab() => _tabController.animateTo(0);

  void _openParcelDetail(
    final BuildContext context,
    final List<Parcel> parcels,
    final Parcel parcel,
  ) {
    final int index = parcels.indexWhere((final Parcel p) => p.id == parcel.id);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => JazlaReviewScreen(
          jazlaName: context.read<JazlaDetailCubit>().state.jazla?.name ?? '',
          parcels: parcels,
          initialIndex: index < 0 ? 0 : index,
        ),
      ),
    );
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

  Future<void> _addParcelDirect(final Parcel parcel) async {
    final JazlaAddParcelCubit addCubit = context.read<JazlaAddParcelCubit>();
    await addCubit.addFreeParcel(parcel.id);
    if (!mounted || addCubit.state.lastAddedParcelId != parcel.id) return;
    await context.read<JazlaDetailCubit>().load();
    if (!mounted) return;
    _goToParcelsTab();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('jazla.add_sheet.added'.tr()),
        action: SnackBarAction(
          label: 'jazla.add_sheet.undo'.tr(),
          onPressed: () async {
            await context.read<JazlaDetailCubit>().removeParcel(parcel.id);
            if (mounted) {
              context.read<JazlaAddParcelCubit>().search(_searchController.text);
            }
          },
        ),
      ),
    );
  }

  Future<void> _editTargetArea(final JazlaDetailCubit cubit) async {
    final Jazla? jazla = cubit.state.jazla;
    if (jazla == null || !mounted) return;
    final JazlaAreaValue? area = await showJazlaAreaDialog(
      context,
      initial: JazlaAreaValue(
        feddan: jazla.targetFeddan,
        qirat: jazla.targetQirat,
        sahm: jazla.targetSahm,
        squareMeters: jazla.targetAreaSqmOverride,
      ),
    );
    if (area == null || !mounted) return;
    await cubit.updateArea(
      feddan: area.feddan,
      qirat: area.qirat,
      sahm: area.sahm,
      squareMeters: area.squareMeters,
    );
  }

  Future<void> _editBasin(final JazlaDetailCubit cubit) async {
    final BasinPickResult? result = await pickBasin(
      context,
      selected: cubit.state.jazla?.basinName,
    );
    if (!mounted || result == null || result.basinName == null) return;
    await cubit.updateBasin(result.basinName);
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

  Future<void> _openBulkApply(
      final String jazlaId, final List<Parcel> parcels) async {
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
            if (state.status == JazlaDetailStatus.notFound ||
                state.jazla == null) {
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ScreenHeader(title: state.jazla!.name),
                            if (state.jazla!.basinName != null)
                              Padding(
                                padding: EdgeInsetsDirectional.only(start: rw(16)),
                                child: Text(
                                  state.jazla!.basinName!,
                                  style: TextStyle(color: colors.textSecondary),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded),
                        tooltip: 'jazla.actions.title'.tr(),
                        onPressed: () => showJazlaActionsSheet(
                          context,
                          jazla: state.jazla!,
                          parcels: parcels,
                          onEditArea: () => _editTargetArea(cubit),
                          onEditBasin: () => _editBasin(cubit),
                          exportExcelAction: JazlaExportButton(
                            jazlaName: state.jazla!.name,
                            parcels: parcels,
                          ),
                          sharePdfAction: JazlaPdfShareButton(
                            jazla: state.jazla!,
                            parcels: parcels,
                          ),
                          onBulkApply: parcels.isEmpty
                              ? () {}
                              : () => _openBulkApply(jazlaId, parcels),
                        ),
                      ),
                      horizontalSpacing(8),
                    ],
                  ),
                ),
                JazlaAreaSummary(jazla: state.jazla!, parcels: parcels),
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
                      ParcelsTab(
                        parcels: parcels,
                        onReorder: cubit.reorder,
                        onTapParcel: (final Parcel p) =>
                            _openParcelDetail(context, parcels, p),
                        onLongPressParcel: (final Parcel p) =>
                            _confirmRemove(context, cubit, p),
                      ),
                      AddParcelTab(
                        searchController: _searchController,
                        onAddTap: _addParcelDirect,
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
