import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../core/router/routes.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/widgets/app_back_button.dart';
import '../data/model/basin_progress.dart';
import '../data/repo/holdings_repository.dart';
import 'widgets/basin_card.dart';

/// Every حوض in the active city with completion progress
/// (APP_CLAUDE.md § 9.2) — reached from `HomeTopBar`'s basins icon.
/// Tapping a card opens [BasinScreen] for its holdings. Reads directly from
/// `HoldingsRepository` (not `HomeCubit`) — this screen is pushed as its
/// own named route, so it has no access to `HomeScreen`'s scoped cubit.
class BasinsPage extends StatefulWidget {
  const BasinsPage({super.key});

  @override
  State<BasinsPage> createState() => _BasinsPageState();
}

class _BasinsPageState extends State<BasinsPage> {
  final HoldingsRepository _repository = getIt<HoldingsRepository>();

  Future<void> _openBasin(final String basinName) async {
    await context.pushNamed(Routes.basin, arguments: basinName);
    if (mounted) setState(() {});
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final List<BasinProgress> basins = _repository.basinSummaries;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: rw(16), vertical: rh(12)),
              child: Row(
                children: [
                  const AppBackButton(),
                  horizontalSpacing(12),
                  Text(
                    'holdings.basin.title'.tr(),
                    style: AppTextStyles.font20Bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: basins.isEmpty
                  ? Center(
                      child: Text(
                        'holdings.home.no_basins'.tr(),
                        style: AppTextStyles.font14Regular
                            .copyWith(color: colors.textHint),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: rw(16))
                          .copyWith(bottom: rh(24)),
                      itemCount: basins.length,
                      itemBuilder: (final BuildContext context, final int i) {
                        final BasinProgress basin = basins[i];
                        return BasinCard(
                          basin: basin,
                          animationIndex: i,
                          onTap: () => _openBasin(basin.basinName),
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
