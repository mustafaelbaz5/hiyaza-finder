import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/widgets/screen_header.dart';
import '../../holdings/data/model/parcel.dart';
import '../../holdings/data/repo/holdings_reader.dart';
import '../../holdings/data/repo/holdings_repository.dart';
import '../data/repo/jazla_repo.dart';
import '../logic/cubit/jazla_detail_cubit.dart';
import '../logic/cubit/jazla_detail_state.dart';
import 'widgets/jazla_add_parcel_launcher.dart';
import 'widgets/jazla_export_button.dart';
import 'widgets/jazla_parcel_tile.dart';

/// Ordered, drag-reorderable list of one Jazla's parcels — tap opens the
/// real, unchanged holding [Routes.holdingDetail] screen; swipe removes the
/// parcel from this Jazla only (never touches the underlying parcel).
class JazlaDetailScreen extends StatelessWidget {
  const JazlaDetailScreen({super.key, required this.jazlaId});

  final String jazlaId;

  @override
  Widget build(final BuildContext context) {
    final String cityId = getIt<HoldingsRepository>().activeCityId ?? '';
    return BlocProvider<JazlaDetailCubit>(
      create: (final _) => JazlaDetailCubit(
        getIt<JazlaRepo>(),
        getIt<HoldingsReader>(),
        jazlaId,
        cityId,
      )..load(),
      child: const _JazlaDetailView(),
    );
  }
}

class _JazlaDetailView extends StatelessWidget {
  const _JazlaDetailView();

  void _openParcelDetail(final BuildContext context, final Parcel parcel) {
    final List<Parcel> group =
        getIt<HoldingsRepository>().parcelsForHolding(parcel.groupKey);
    context.pushNamed(Routes.holdingDetail, arguments: group);
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final JazlaDetailCubit cubit = context.read<JazlaDetailCubit>();

    return Scaffold(
      backgroundColor: colors.background,
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

            final List<Parcel> parcels = state.parcels;

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
                      JazlaExportButton(
                        jazlaName: state.jazla!.name,
                        parcels: parcels,
                      ),
                      horizontalSpacing(8),
                    ],
                  ),
                ),
                Expanded(
                  child: parcels.isEmpty
                      ? Center(
                          child: Text(
                            'jazla.detail.empty'.tr(),
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: EdgeInsets.fromLTRB(rw(16), 0, rw(16), rh(80)),
                          itemCount: parcels.length,
                          onReorder: (final int oldIndex, int newIndex) {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final List<String> ids =
                                parcels.map((final Parcel p) => p.id).toList();
                            final String moved = ids.removeAt(oldIndex);
                            ids.insert(newIndex, moved);
                            cubit.reorder(ids);
                          },
                          itemBuilder: (final BuildContext context, final int i) {
                            final Parcel parcel = parcels[i];
                            return Dismissible(
                              key: ValueKey<String>(parcel.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: AlignmentDirectional.centerEnd,
                                padding: EdgeInsets.symmetric(horizontal: rw(20)),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: colors.error.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.delete_outline_rounded, color: colors.error),
                              ),
                              onDismissed: (final _) => cubit.removeParcel(parcel.id),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: JazlaParcelTile(
                                  index: i + 1,
                                  parcel: parcel,
                                  onTap: () => _openParcelDetail(context, parcel),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showJazlaAddParcelSheet(context, jazlaId: cubit.jazlaId);
          // The add-parcel sheet uses its own, separate cubit instance —
          // reload this screen's cubit so a parcel added there (or via the
          // reused add-person/add-parcel-for-existing-person flow it can
          // launch) shows up immediately without leaving and re-entering.
          cubit.load();
        },
        icon: const Icon(Icons.add),
        label: Text('jazla.detail.add_parcel'.tr()),
      ),
    );
  }
}
