import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/router/routes.dart';
import 'package:hiyaza_finder/core/utils/extensions/context_ext.dart';
import 'package:hiyaza_finder/core/utils/spacing.dart';
import 'package:hiyaza_finder/core/widgets/screen_header.dart';
import 'package:hiyaza_finder/core/widgets/ui/dialogs/app_dialogs.dart';
import 'package:hiyaza_finder/core/widgets/ui/dialogs/text_input_dialog.dart';
import 'package:hiyaza_finder/features/jazla/data/local/jazla_preferences.dart';
import 'package:hiyaza_finder/features/jazla/data/model/jazla.dart';
import 'package:hiyaza_finder/features/jazla/logic/cubit/jazla_list_cubit.dart';
import 'package:hiyaza_finder/features/jazla/logic/cubit/jazla_list_state.dart';
import 'package:hiyaza_finder/features/jazla/ui/widgets/jazla_card.dart';
import 'package:hiyaza_finder/features/jazla/ui/widgets/jazla_create_wizard.dart';
import 'package:hiyaza_finder/features/jazla/ui/widgets/jazla_sort_sheet.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/repo/parcel_catalog_repository.dart';

class JazlaListView extends StatelessWidget {
  const JazlaListView({super.key});

  Future<void> _createJazla(
      final BuildContext context, final JazlaListCubit cubit) async {
    final List<String> basins =
        getIt<ParcelCatalogRepository>().availableBasins;
    if (basins.isEmpty) {
      await AppDialogs.showWarning(context,
          message: 'jazla.basin_required'.tr());
      return;
    }
    final JazlaCreateValue? value = await showJazlaCreateWizard(
      context,
      basins: basins,
    );
    if (value != null) {
      await cubit.createJazla(
        value.name,
        basinName: value.basinName,
        targetFeddan: value.area.feddan,
        targetQirat: value.area.qirat,
        targetSahm: value.area.sahm,
        targetAreaSqm: value.area.squareMeters,
      );
    }
  }

  Future<void> _renameJazla(
    final BuildContext context,
    final JazlaListCubit cubit,
    final Jazla jazla,
  ) async {
    final String? name = await showTextInputDialog(
      context,
      title: 'jazla.name_hint'.tr(),
      initialValue: jazla.name,
    );
    if (name != null && name.trim().isNotEmpty) {
      await cubit.renameJazla(jazla.id, name);
    }
  }

  Future<void> _pickSort(
      final BuildContext context, final JazlaListCubit cubit) async {
    final JazlaSort? sort = await showJazlaSortSheet(
      context,
      selected: cubit.state.sort,
    );
    if (sort != null) await cubit.setSort(sort);
  }

  void _showOptions(
    final BuildContext context,
    final JazlaListCubit cubit,
    final Jazla jazla,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (final BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text('jazla.rename'.tr(), textAlign: TextAlign.right),
              onTap: () {
                Navigator.pop(sheetContext);
                _renameJazla(context, cubit, jazla);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text('jazla.delete'.tr(), textAlign: TextAlign.right),
              onTap: () {
                Navigator.pop(sheetContext);
                AppDialogs.showConfirm(
                  context,
                  title: 'jazla.delete_confirm_title'.tr(),
                  message: 'jazla.delete_confirm_message'.tr(),
                  onConfirm: () {
                    cubit.deleteJazla(jazla.id);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final JazlaListCubit cubit = context.read<JazlaListCubit>();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: ScreenHeader(title: 'jazla.title'.tr())),
                    IconButton(
                      tooltip: 'jazla.sort.title'.tr(),
                      icon: const Icon(Icons.sort_rounded),
                      onPressed: () => _pickSort(context, cubit),
                    ),
                  ],
                ),
                Expanded(
                  child: BlocBuilder<JazlaListCubit, JazlaListState>(
                    builder: (final BuildContext context,
                        final JazlaListState state) {
                      if (state.status == JazlaListStatus.loading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state.jazlas.isEmpty) {
                        return Center(
                          child: Text(
                            'jazla.empty_list'.tr(),
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: EdgeInsets.fromLTRB(rw(16), 0, rw(16), rh(80)),
                        itemCount: state.jazlas.length,
                        itemBuilder: (final BuildContext context, final int i) {
                          final Jazla jazla = state.jazlas[i];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: i == state.jazlas.length - 1 ? 0 : rh(12),
                            ),
                            child: JazlaCard(
                              jazla: jazla,
                              onTap: () async {
                                await context.pushNamed(
                                  Routes.jazlaDetail,
                                  arguments: jazla.id,
                                );
                                // The detail screen mutates parcels/parcelIds
                                // through its own, separate cubit instance —
                                // reload so this card's count reflects
                                // whatever changed there (add/remove/reorder)
                                // without leaving and re-entering this screen.
                                cubit.load();
                              },
                              onLongPress: () =>
                                  _showOptions(context, cubit, jazla),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            PositionedDirectional(
              bottom: rh(20),
              end: rw(20),
              child: FloatingActionButton.extended(
                onPressed: () => _createJazla(context, cubit),
                icon: const Icon(Icons.add),
                label: Text('jazla.new_jazla'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
