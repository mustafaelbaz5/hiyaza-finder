import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hiyaza_finder/core/widgets/ui/dialogs/text_input_dialog.dart';
import 'package:hiyaza_finder/features/jazla/ui/widgets/add_parcel_tab.dart';
import 'package:hiyaza_finder/features/jazla/ui/widgets/jazla_detail_app_bar.dart';
import 'package:hiyaza_finder/features/jazla/ui/widgets/parcels_tab.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../core/router/routes.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/widgets/ui/dialogs/app_dialogs.dart';
import '../../parcel_add/data/local/existing_person_parcel_template.dart';
import '../../parcel_add/data/model/add_record_args.dart';
import '../../parcel_add/ui/widgets/basin_picker.dart';
import '../../parcel_catalog/data/model/parcel.dart';
import '../../parcel_catalog/data/repo/holdings_reader.dart';
import '../../parcel_catalog/data/repo/holdings_writer.dart';
import '../../parcel_catalog/data/repo/parcel_catalog_repository.dart';
import '../../parcel_editor/logic/cubit/parcel_editor_cubit.dart';
import '../../parcel_editor/logic/cubit/parcel_editor_state.dart';
import '../data/local/jazla_parcel_defaults_policy.dart';
import '../data/local/jazla_search_service.dart';
import '../data/model/jazla.dart';
import '../data/repo/jazla_repo.dart';
import '../../jazla_transfer/data/repo/jazla_transfer_repository.dart';
import '../../jazla_transfer/logic/cubit/jazla_export_cubit.dart';
import '../../jazla_transfer/ui/widgets/jazla_transfer_export_button.dart';
import '../logic/cubit/jazla_add_parcel_cubit.dart';
import '../logic/cubit/jazla_detail_cubit.dart';
import '../logic/cubit/jazla_detail_state.dart';
import 'jazla_review_screen.dart';
import 'widgets/jazla_actions_sheet.dart';
import 'widgets/jazla_area_dialog.dart';
import 'widgets/jazla_bulk_apply_sheet.dart';
import 'widgets/jazla_export_button.dart';
import 'widgets/jazla_quick_view_sheet.dart';

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
    final String cityId = getIt<ParcelCatalogRepository>().activeCityId ?? '';
    return MultiBlocProvider(
      providers: [
        BlocProvider<JazlaDetailCubit>(
          create: (final _) => JazlaDetailCubit(
            getIt<JazlaRepo>(),
            getIt<ParcelCatalogReader>(),
            jazlaId,
            cityId,
            getIt<ParcelCatalogWriter>(),
            getIt<JazlaTransferRepository>(),
          )..load(),
        ),
        BlocProvider<JazlaAddParcelCubit>(
          create: (final _) => JazlaAddParcelCubit(
            getIt<JazlaRepo>(),
            getIt<ParcelCatalogReader>(),
            getIt<JazlaSearchService>(),
            jazlaId,
            cityId,
          )..initializeOwnership(),
        ),
        BlocProvider<ParcelEditorCubit>(
          create: (final _) => getIt<ParcelEditorCubit>(),
        ),
        BlocProvider<ParcelEditorCubit>(
          create: (final _) => getIt<ParcelEditorCubit>(),
        ),
        BlocProvider<JazlaExportCubit>(
          create: (final _) => JazlaExportCubit(
            getIt<JazlaTransferRepository>(),
            getIt<ParcelCatalogRepository>(),
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
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _restoreSearchFocus() {
    WidgetsBinding.instance.addPostFrameCallback((final _) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  Future<void> _openParcelDetail(
    final BuildContext context,
    final List<Parcel> parcels,
    final Parcel parcel,
  ) async {
    final int index = parcels.indexWhere((final Parcel p) => p.id == parcel.id);
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (final _) => JazlaReviewScreen(
          jazlaName: context.read<JazlaDetailCubit>().state.jazla?.name ?? '',
          parcels: parcels,
          initialIndex: index < 0 ? 0 : index,
        ),
      ),
    );
    if (context.mounted) {
      context.read<JazlaDetailCubit>().refreshVisibleParcels();
    }
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
        _removeParcel(context, cubit, parcel.id);
      },
    );
  }

  Future<void> _removeParcel(
    final BuildContext context,
    final JazlaDetailCubit cubit,
    final String parcelId,
  ) async {
    final bool removed = await cubit.removeParcel(parcelId);
    if (!context.mounted) return;
    if (removed) {
      context.read<JazlaAddParcelCubit>().markParcelRemoved(parcelId);
    } else {
      context.showErrorSnackBar(
        context.read<JazlaDetailCubit>().state.errorMessage ??
            'jazla.detail.remove_confirm_message'.tr(),
      );
    }
  }

  Future<void> _addParcelDirect(final Parcel parcel) async {
    final JazlaDetailCubit detailCubit = context.read<JazlaDetailCubit>();
    final Future<bool> persisted = detailCubit.addParcel(parcel);
    final bool added = await persisted;
    if (!mounted) return;
    if (!added) {
      context.showErrorSnackBar(
        detailCubit.state.errorMessage ?? 'jazla.add_sheet.add_failed'.tr(),
      );
      return;
    }
    context
        .read<JazlaAddParcelCubit>()
        .markParcelAdded(parcel.id, detailCubit.state.jazla?.name ?? '');
    _restoreSearchFocus();
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
    if (mounted) {
      context
          .read<JazlaAddParcelCubit>()
          .setPreferredBasin(cubit.state.jazla?.basinName);
    }
  }

  Future<void> _addNewPerson() async {
    final Jazla? jazla = context.read<JazlaDetailCubit>().state.jazla;
    final Parcel initial = JazlaParcelDefaultsPolicy.apply(
      const Parcel(holdingId: '', landNumber: '0', holdingsCount: 1),
      jazla?.parcelDefaults,
    );
    final Parcel? created = await context.pushNamed<Parcel>(
      Routes.addRecord,
      arguments: _addRecordArgs(initial, jazla),
    );
    if (created == null || !mounted) return;
    await _addParcelDirect(created);
  }

  Future<void> _addParcelForExistingPerson(final Parcel source) async {
    final Jazla? jazla = context.read<JazlaDetailCubit>().state.jazla;
    final Parcel initial = JazlaParcelDefaultsPolicy.apply(
      existingPersonParcelTemplate(source),
      jazla?.parcelDefaults,
    );
    final Parcel? created = await context.pushNamed<Parcel>(
      Routes.addRecord,
      arguments: AddRecordArgs(
        initialParcel: initial,
        parentHoldingId: source.id,
        suggestedBasinName: jazla?.basinName,
        suggestedBasinCode: _basinCodeFor(jazla?.basinName),
      ),
    );
    if (created == null || !mounted) return;
    await _addParcelDirect(created);
  }

  AddRecordArgs _addRecordArgs(final Parcel initial, final Jazla? jazla) =>
      AddRecordArgs(
        initialParcel: initial,
        suggestedBasinName: jazla?.basinName,
        suggestedBasinCode: _basinCodeFor(jazla?.basinName),
      );

  String? _basinCodeFor(final String? basinName) {
    final String normalized = basinName?.trim() ?? '';
    if (normalized.isEmpty) return null;
    return getIt<ParcelCatalogRepository>().basinByName(normalized)?.basinCode;
  }

  Future<void> _editThenAdd(final Parcel parcel) async {
    final ParcelEditorCubit editor = context.read<ParcelEditorCubit>();
    final Parcel? updated = await showJazlaQuickViewSheet(
      context,
      parcel: parcel,
      onSave: (final Parcel draft) async {
        await editor.save(draft);
        final ParcelEditorState editState = editor.state;
        if (editState.status == ParcelEditorStatus.failure) {
          throw editState.error ?? StateError('Unable to save parcel');
        }
        return editState.parcel;
      },
    );
    if (updated != null && mounted) await _addParcelDirect(updated);
  }

  Future<void> _openBulkApply(
      final String jazlaId, final List<Parcel> parcels) async {
    await showJazlaBulkApplySheet(
      context,
      jazlaId: jazlaId,
      parcels: parcels,
      onApply: ({
        required final field,
        required final value,
        required final parcelIds,
        required final onProgress,
      }) =>
          context.read<JazlaDetailCubit>().applyBulkField(
                field: field,
                value: value,
                parcelIds: parcelIds,
                onProgress: onProgress,
              ),
      onDefaultChanged: (final field, final value) =>
          context.read<JazlaDetailCubit>().updateParcelDefault(field, value),
    );
    if (mounted) context.read<JazlaDetailCubit>().refreshVisibleParcels();
  }

  Future<void> _renameJazla(final JazlaDetailCubit cubit) async {
    final Jazla? jazla = cubit.state.jazla;
    if (jazla == null) return;
    final String? name = await showTextInputDialog(
      context,
      title: 'jazla.rename'.tr(),
      initialValue: jazla.name,
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    await cubit.renameJazla(name);
  }

  Future<void> _deleteJazla(final JazlaDetailCubit cubit) async {
    await AppDialogs.showConfirm(
      context,
      title: 'jazla.delete_confirm_title'.tr(),
      message: 'jazla.delete_confirm_message'.tr(),
      confirmText: 'jazla.delete'.tr(),
      onConfirm: () async {
        await cubit.deleteJazla();
        if (mounted && cubit.state.status == JazlaDetailStatus.notFound) {
          Navigator.pop(context);
        }
      },
    );
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      backgroundColor: colors.background,
      resizeToAvoidBottomInset: true,
      body: BlocBuilder<JazlaDetailCubit, JazlaDetailState>(
        builder: (final BuildContext context, final JazlaDetailState state) {
          if (state.status == JazlaDetailStatus.loading) {
            return const SafeArea(
                child: Center(child: CircularProgressIndicator()));
          }
          if (state.status == JazlaDetailStatus.notFound ||
              state.jazla == null) {
            return SafeArea(
              child: Center(child: Text('jazla.empty_list'.tr())),
            );
          }

          final String jazlaId = state.jazla!.id;
          final List<Parcel> parcels = state.parcels;
          final JazlaDetailCubit cubit = context.read<JazlaDetailCubit>();

          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                JazlaDetailAppBar(
                  jazla: state.jazla!,
                  onActionsPressed: () => showJazlaActionsSheet(
                    context,
                    jazla: state.jazla!,
                    parcels: parcels,
                    onRename: () => _renameJazla(cubit),
                    onEditArea: () => _editTargetArea(cubit),
                    onEditBasin: () => _editBasin(cubit),
                    exportExcelAction: JazlaExportButton(
                      jazla: state.jazla!,
                      parcels: parcels,
                    ),
                    exportTransferAction: BlocProvider.value(
                      value: context.read<JazlaExportCubit>(),
                      child: JazlaTransferExportButton(
                        jazla: state.jazla!,
                        parcels: parcels,
                      ),
                    ),
                    onBulkApply: () => _openBulkApply(jazlaId, parcels),
                    onDelete: () => _deleteJazla(cubit),
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
                      ParcelsTab(
                        parcels: parcels,
                        onReorder: cubit.reorder,
                        onTapParcel: (final Parcel p) =>
                            _openParcelDetail(context, parcels, p),
                        onRemoveParcel: (final Parcel p) =>
                            _confirmRemove(context, cubit, p),
                      ),
                      AddParcelTab(
                        searchController: _searchController,
                        searchFocusNode: _searchFocusNode,
                        onAddTap: _addParcelDirect,
                        onEditTap: _editThenAdd,
                        onAddNewPerson: _addNewPerson,
                        onAddForPerson: _addParcelForExistingPerson,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
