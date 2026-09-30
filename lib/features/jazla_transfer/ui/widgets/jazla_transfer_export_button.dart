import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../jazla/data/model/jazla.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../../logic/cubit/jazla_export_cubit.dart';
import '../../logic/cubit/jazla_export_state.dart';

enum _JazlaExportChoice { save, share }

class JazlaTransferExportButton extends StatelessWidget {
  const JazlaTransferExportButton({
    super.key,
    required this.jazla,
    required this.parcels,
  });

  final Jazla jazla;
  final List<Parcel> parcels;

  Future<void> _confirm(final BuildContext context) async {
    final _JazlaExportChoice? choice =
        await showModalBottomSheet<_JazlaExportChoice>(
      context: context,
      useSafeArea: true,
      backgroundColor: context.customColors.surface,
      builder: (final BuildContext sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'jazla.transfer.export_title'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            Text(
              'jazla.transfer.privacy_warning'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(
                sheetContext,
                _JazlaExportChoice.save,
              ),
              icon: const Icon(Icons.save_alt_rounded),
              label: Text('jazla.transfer.save_only'.tr()),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                sheetContext,
                _JazlaExportChoice.share,
              ),
              icon: const Icon(Icons.ios_share_rounded),
              label: Text('jazla.transfer.save_and_share'.tr()),
            ),
          ],
        ),
      ),
    );
    if (choice != null && context.mounted) {
      await context.read<JazlaExportCubit>().exportAndShare(
            jazla: jazla,
            parcels: parcels,
            share: choice == _JazlaExportChoice.share,
          );
    }
  }

  @override
  Widget build(final BuildContext context) {
    return BlocConsumer<JazlaExportCubit, JazlaExportState>(
      listener: (final BuildContext context, final JazlaExportState state) {
        if (state.status == JazlaExportStatus.success) {
          context.showSuccessSnackBar(
            state.errorMessage == 'jazla.transfer.share_failed'
                ? 'jazla.transfer.saved_share_failed'.tr()
                : 'jazla.transfer.export_success'.tr(),
          );
        } else if (state.status == JazlaExportStatus.error) {
          context.showErrorSnackBar(_message(state.errorMessage));
        }
      },
      builder: (final BuildContext context, final JazlaExportState state) {
        final bool busy = state.status == JazlaExportStatus.exporting;
        return IconButton(
          tooltip: 'jazla.transfer.export_title'.tr(),
          onPressed: busy ? null : () => _confirm(context),
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share_rounded),
          color: AppColors.primary200,
        );
      },
    );
  }

  String _message(final String? key) => switch (key) {
        'jazla.transfer.missing_context' => 'jazla.transfer.error_context'.tr(),
        _ => 'jazla.transfer.error_export'.tr(),
      };
}
