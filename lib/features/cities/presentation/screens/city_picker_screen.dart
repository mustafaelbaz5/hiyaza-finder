import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/city_snapshot.dart';
import '../cubit/city_picker_cubit.dart';
import '../cubit/city_state.dart';
import '../widgets/city_tile.dart';

/// Lists published cities and downloads the picked one, then pops with
/// `true` so the caller (`HomeScreen`'s empty state) knows to adopt
/// whatever `HoldingsRepository` now holds — mirrors how the file-status
/// screen's caller re-syncs after returning.
class CityPickerScreen extends StatefulWidget {
  const CityPickerScreen({super.key});

  @override
  State<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  City? _downloadingCity;

  @override
  void initState() {
    super.initState();
    context.read<CityPickerCubit>().loadCities();
  }

  Future<void> _pick(final City city) async {
    if (_downloadingCity != null) return;
    setState(() => _downloadingCity = city);

    final CitySnapshot? snapshot =
        await context.read<CityPickerCubit>().downloadAndActivate(city);

    if (!mounted) return;
    if (snapshot != null) {
      Navigator.pop(context, snapshot);
      return;
    }
    setState(() => _downloadingCity = null);
    final String? error = context.read<CityPickerCubit>().state.errorMessage;
    if (error != null) context.showErrorSnackBar(error);
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            verticalSpacing(16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: rw(16)),
              child: Row(
                children: [
                  const AppBackButton(),
                  horizontalSpacing(12),
                  Expanded(
                    child: Text(
                      'cities.picker.title'.tr(),
                      style: AppTextStyles.font20Bold.copyWith(
                        color: colors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            verticalSpacing(16),
            Expanded(
              child: BlocBuilder<CityPickerCubit, CityPickerState>(
                builder: (final BuildContext context, final CityPickerState state) {
                  if (state.status == CityPickerStatus.loading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary200,
                      ),
                    );
                  }

                  if (state.status == CityPickerStatus.error &&
                      state.cities.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: rw(24)),
                        child: Text(
                          state.errorMessage ?? 'errors.unknown'.tr(),
                          style: AppTextStyles.font16Regular.copyWith(
                            color: colors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ).animate().fadeIn(duration: 250.ms);
                  }

                  if (state.cities.isEmpty) {
                    return Center(
                      child: Text(
                        'cities.picker.empty'.tr(),
                        style: AppTextStyles.font16Regular.copyWith(
                          color: colors.textHint,
                        ),
                      ),
                    ).animate().fadeIn(duration: 250.ms);
                  }

                  return AbsorbPointer(
                    absorbing: _downloadingCity != null,
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: rw(16),
                      ).copyWith(bottom: rh(24)),
                      itemCount: state.cities.length,
                      itemBuilder: (final BuildContext context, final int i) {
                        final City city = state.cities[i];
                        return CityTile(
                          city: city,
                          isDownloading: _downloadingCity?.id == city.id,
                          onTap: () => _pick(city),
                        )
                            .animate()
                            .fadeIn(duration: 220.ms, delay: (i * 30).ms)
                            .slideY(
                              begin: 0.08,
                              end: 0,
                              duration: 220.ms,
                              delay: (i * 30).ms,
                              curve: Curves.easeOutCubic,
                            );
                      },
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
