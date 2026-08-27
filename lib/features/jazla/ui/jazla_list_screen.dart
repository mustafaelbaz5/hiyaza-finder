import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/ui/dialogs/app_dialogs.dart';
import '../../../core/widgets/ui/dialogs/text_input_dialog.dart';
import '../../holdings/data/repo/holdings_repository.dart';
import '../data/model/jazla.dart';
import '../data/repo/jazla_repo.dart';
import '../logic/cubit/jazla_list_cubit.dart';
import '../logic/cubit/jazla_list_state.dart';
import 'widgets/jazla_card.dart';

/// Lists every [Jazla] for the active city — tap opens its detail screen,
/// long-press offers rename/delete, "+ جزلة جديدة" creates a new one.
class JazlaListScreen extends StatelessWidget {
  const JazlaListScreen({super.key});

  @override
  Widget build(final BuildContext context) {
    final String cityId = getIt<HoldingsRepository>().activeCityId ?? '';
    return BlocProvider<JazlaListCubit>(
      create: (final _) => JazlaListCubit(getIt<JazlaRepo>(), cityId)..load(),
      child: const _JazlaListView(),
    );
  }
}

class _JazlaListView extends StatelessWidget {
  const _JazlaListView();

  Future<void> _createJazla(final BuildContext context, final JazlaListCubit cubit) async {
    final String? name = await showTextInputDialog(
      context,
      title: 'jazla.name_hint'.tr(),
      initialValue: '',
    );
    if (name != null && name.trim().isNotEmpty) {
      await cubit.createJazla(name);
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
                    Navigator.pop(context);
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
                ScreenHeader(title: 'jazla.title'.tr()),
                Expanded(
                  child: BlocBuilder<JazlaListCubit, JazlaListState>(
                    builder: (final BuildContext context, final JazlaListState state) {
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
                          return JazlaCard(
                            jazla: jazla,
                            onTap: () => context.pushNamed(
                              Routes.jazlaDetail,
                              arguments: jazla.id,
                            ),
                            onLongPress: () => _showOptions(context, cubit, jazla),
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
