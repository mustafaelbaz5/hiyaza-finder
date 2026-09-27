import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hiyaza_finder/core/utils/spacing.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/widgets/ui/buttons/app_icon_button.dart';
import '../../parcel_catalog/data/model/parcel.dart';
import '../../parcel_catalog/data/repo/holdings_reader.dart';
import '../../parcel_catalog/data/repo/holdings_writer.dart';
import '../../parcel_catalog/data/repo/parcel_detail_actions.dart';
import '../../parcel_details/ui/widgets/parcel_detail_card.dart';
import '../logic/cubit/jazla_review_cubit.dart';
import '../logic/cubit/jazla_review_state.dart';

class JazlaReviewScreen extends StatelessWidget {
  const JazlaReviewScreen({
    super.key,
    required this.jazlaName,
    required this.parcels,
    required this.initialIndex,
  });

  final String jazlaName;
  final List<Parcel> parcels;
  final int initialIndex;

  @override
  Widget build(final BuildContext context) {
    return BlocProvider<JazlaReviewCubit>(
      create: (final _) => JazlaReviewCubit(
        getIt<ParcelCatalogWriter>(),
        getIt<ParcelDetailActions>(),
        getIt<ParcelCatalogReader>(),
        parcels: parcels,
        initialIndex: initialIndex,
      ),
      child: _JazlaReviewView(jazlaName: jazlaName),
    );
  }
}

class _JazlaReviewView extends StatelessWidget {
  const _JazlaReviewView({required this.jazlaName});

  final String jazlaName;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: BlocBuilder<JazlaReviewCubit, JazlaReviewState>(
                buildWhen: (final previous, final current) =>
                    previous.index != current.index ||
                    previous.parcels.length != current.parcels.length,
                builder:
                    (final BuildContext context, final JazlaReviewState state) {
                  final JazlaReviewCubit cubit =
                      context.read<JazlaReviewCubit>();
                  return Row(
                    children: [
                      AppIconButton(
                          tooltip: 'jazla.review.back'.tr(),
                          icon: Icons.arrow_back_ios_rounded,
                          onPressed: () => context.pop()),
                      horizontalSpacing(12),
                      Expanded(
                        child: Text(
                          jazlaName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.font16SemiBold
                              .copyWith(color: colors.textPrimary),
                        ),
                      ),
                      AppIconButton(
                        tooltip: 'jazla.review.previous'.tr(),
                        onPressed: state.canGoPrevious ? cubit.previous : null,
                        icon: Icons.arrow_back_ios_rounded,
                      ),
                      horizontalSpacing(8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Text(
                          '${state.index + 1} ${'jazla.review.of'.tr()} ${state.parcels.length}',
                          style: AppTextStyles.font14Regular
                              .copyWith(color: colors.textSecondary),
                        ),
                      ),
                      horizontalSpacing(8),
                      AppIconButton(
                        tooltip: 'jazla.review.next'.tr(),
                        onPressed: state.canGoNext ? cubit.next : null,
                        icon: Icons.arrow_forward_ios_rounded,
                      ),
                      horizontalSpacing(8),
                    ],
                  );
                },
              ),
            ),
            // Body content
            Expanded(
              child: BlocBuilder<JazlaReviewCubit, JazlaReviewState>(
                buildWhen: (final previous, final current) =>
                    previous.index != current.index ||
                    previous.parcels != current.parcels,
                builder:
                    (final BuildContext context, final JazlaReviewState state) {
                  final JazlaReviewCubit cubit =
                      context.read<JazlaReviewCubit>();
                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      ParcelDetailCard(
                        parcel: state.parcel,
                        onFieldChanged: cubit.save,
                        onCompleted: cubit.reflectCompletion,
                        availableBasins: cubit.availableBasins,
                        parcelsForHolding: cubit.parcelsForHolding,
                        setParcelCompleted: cubit.setCompleted,
                        onReopen: cubit.reopen,
                        onRegenerate: cubit.regenerate,
                      ),
                    ],
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
