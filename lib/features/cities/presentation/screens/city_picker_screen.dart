import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/custom_text_form_.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/city_snapshot.dart';
import '../cubit/city_picker_cubit.dart';
import '../cubit/city_state.dart';
import '../widgets/city_tile.dart';

/// Lists published cities and downloads the picked one, then pops with
/// `true` so the caller (`HomeScreen`'s empty state) knows to adopt
/// whatever `HoldingsRepository` now holds — mirrors how the file-status
/// screen's caller re-syncs after returning.
///
/// Search is purely client-side over whatever `CityPickerCubit` already
/// loaded — the full published-cities list is small enough (tens, not
/// thousands, of rows) that a live network query per keystroke would be
/// wasted round-trips; filtering the in-memory list keeps typing instant
/// and still scales fine as the city count grows.
class CityPickerScreen extends StatefulWidget {
  const CityPickerScreen({super.key});

  @override
  State<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  City? _downloadingCity;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    context.read<CityPickerCubit>().loadCities();
    _searchController.addListener(() {
      if (_query == _searchController.text) return;
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  /// Simple substring match on city name — city/association names are
  /// short and typically typed exactly, so this stays intentionally
  /// lighter-weight than `HoldingSearchService`'s Arabic-normalized
  /// tiered scoring (which exists for large, messy holder-name datasets;
  /// a city list doesn't need that machinery).
  List<City> _filter(final List<City> cities) {
    final String trimmed = _query.trim();
    if (trimmed.isEmpty) return cities;
    return cities
        .where((final City c) =>
            c.name.toLowerCase().contains(trimmed.toLowerCase()))
        .toList();
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return LayoutBuilder(
      builder: (final BuildContext context, final BoxConstraints constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double horizontalPadding = isTablet ? rw(64) : rw(16);

        return Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                verticalSpacing(16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                      verticalSpacing(16),
                      CustomTextForm(
                        hintText: 'cities.picker.search_hint'.tr(),
                        controller: _searchController,
                        isRTL: true,
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: colors.iconSecondary,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: Icon(Icons.close_rounded,
                                    color: colors.iconSecondary),
                                tooltip: 'holdings.search.clear'.tr(),
                                onPressed: () => _searchController.clear(),
                              ),
                      ),
                    ],
                  ),
                ),
                verticalSpacing(12),
                Expanded(
                  child: BlocBuilder<CityPickerCubit, CityPickerState>(
                    builder: (final BuildContext context,
                        final CityPickerState state) {
                      if (state.status == CityPickerStatus.loading) {
                        return _LoadingList(
                            horizontalPadding: horizontalPadding);
                      }

                      if (state.status == CityPickerStatus.error &&
                          state.cities.isEmpty) {
                        return _ErrorState(
                          message: state.errorMessage ?? 'errors.unknown'.tr(),
                          onRetry: () =>
                              context.read<CityPickerCubit>().loadCities(),
                        );
                      }

                      if (state.cities.isEmpty) {
                        return _EmptyState(
                          icon: Icons.location_city_rounded,
                          title: 'cities.picker.empty'.tr(),
                        );
                      }

                      final List<City> filtered = _filter(state.cities);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_query.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                      horizontal: horizontalPadding)
                                  .copyWith(bottom: rh(8)),
                              child: Text(
                                'cities.picker.results_count'.tr(
                                  namedArgs: {
                                    'count': filtered.length.toString()
                                  },
                                ),
                                style: AppTextStyles.font12Regular.copyWith(
                                  color: colors.textHint,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          Expanded(
                            child: filtered.isEmpty
                                ? _EmptyState(
                                    icon: Icons.search_off_rounded,
                                    title: 'cities.picker.no_results'.tr(
                                      namedArgs: {'query': _query.trim()},
                                    ),
                                    subtitle:
                                        'cities.picker.no_results_hint'.tr(),
                                  )
                                : AbsorbPointer(
                                    absorbing: _downloadingCity != null,
                                    child: ListView.builder(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: horizontalPadding,
                                      ).copyWith(bottom: rh(24)),
                                      itemCount: filtered.length,
                                      itemBuilder: (final BuildContext context,
                                          final int i) {
                                        final City city = filtered[i];
                                        return CityTile(
                                          key: ValueKey<String>(city.id),
                                          city: city,
                                          isDownloading:
                                              _downloadingCity?.id == city.id,
                                          onTap: () => _pick(city),
                                        )
                                            .animate(
                                                key: ValueKey<String>(
                                                    '${city.id}-anim'))
                                            .fadeIn(
                                              duration: 200.ms,
                                              delay: (i * 20).ms,
                                            )
                                            .slideY(
                                              begin: 0.06,
                                              end: 0,
                                              duration: 200.ms,
                                              delay: (i * 20).ms,
                                              curve: Curves.easeOutCubic,
                                            );
                                      },
                                    ),
                                  ),
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
      },
    );
  }
}

/// Skeleton placeholder shown while cities load — communicates "content is
/// coming here" instead of a bare spinner floating in empty space.
class _LoadingList extends StatelessWidget {
  const _LoadingList({required this.horizontalPadding});

  final double horizontalPadding;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding)
          .copyWith(top: rh(4)),
      itemCount: 6,
      itemBuilder: (final BuildContext context, final int i) => Container(
        height: rh(72),
        margin: EdgeInsets.only(bottom: rh(10)),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
      )
          .animate(
              onPlay: (final AnimationController c) => c.repeat(reverse: true))
          .fadeIn(duration: 700.ms, delay: (i * 60).ms)
          .then()
          .custom(
            duration: 700.ms,
            builder: (final BuildContext context, final double value,
                    final Widget child) =>
                Opacity(opacity: 0.55 + (0.45 * value), child: child),
          ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: rw(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colors.textHint),
            verticalSpacing(12),
            Text(
              title,
              style:
                  AppTextStyles.font16Regular.copyWith(color: colors.textHint),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              verticalSpacing(4),
              Text(
                subtitle!,
                style: AppTextStyles.font12Regular
                    .copyWith(color: colors.textHint),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: rw(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: AppColors.red200),
            verticalSpacing(12),
            Text(
              message,
              style: AppTextStyles.font16Regular
                  .copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            verticalSpacing(16),
            TextButton(
              onPressed: onRetry,
              child: Text('errors.retry'.tr()),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}
