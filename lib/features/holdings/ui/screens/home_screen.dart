import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/empty_body.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/error_body.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/file_info_card.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/home_top_bar.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/service/voice_search_service.dart';
import '../../../../core/settings/ui/settings_sheet.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_form_.dart';
import '../../../cities/domain/entities/city_snapshot.dart';
import '../../data/repository/holdings_repository.dart';
import '../../domain/entities/parcel.dart';
import '../../logic/cubit/home_cubit.dart';
import '../../logic/cubit/home_state.dart';
import '../../logic/services/holding_search_service.dart';
import '../widgets/association_name_sheet.dart';
import '../widgets/basin_filter_sheet.dart';
import '../widgets/city_stale_banner.dart';
import '../widgets/recommendation_list.dart';
import 'add_record_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  // Voice search is Android-only: speech_to_text's desktop support is too
  // unreliable to expose on Windows.
  final VoiceSearchService? _voiceService =
      defaultTargetPlatform == TargetPlatform.android
          ? getIt<VoiceSearchService>()
          : null;
  bool _isListening = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    if (_isListening) _voiceService?.stopListening();
    super.dispose();
  }

  void _onQueryChanged(final String query, final HomeCubit cubit) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      cubit.search(query);
    });
  }

  Future<void> _toggleVoiceSearch(final HomeCubit cubit) async {
    final VoiceSearchService? voice = _voiceService;
    if (voice == null) return;

    if (_isListening) {
      await voice.stopListening();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    final String localeId =
        context.locale.languageCode == 'ar' ? 'ar-EG' : 'en-US';
    final bool started = await voice.startListening(
      localeId: localeId,
      onResult: (final String text) {
        _controller
          ..text = text
          ..selection = TextSelection.collapsed(offset: text.length);
        _onQueryChanged(text, cubit);
      },
      onDone: () {
        if (mounted) setState(() => _isListening = false);
      },
    );

    if (!mounted) return;
    if (!started) {
      context.showErrorSnackBar('holdings.search.mic_permission_denied'.tr());
      return;
    }
    setState(() => _isListening = true);
  }

  void _openHistory() => context.pushNamed(Routes.fileHistory);

  Future<void> _openBasinFilter(final HomeCubit cubit) async {
    final HomeState state = cubit.state;
    final String? selected = await showBasinFilterSheet(
      context,
      basins: state.availableBasins,
      selected: state.selectedBasin,
      holdingCounts: getIt<HoldingsRepository>().basinHoldingCounts,
    );
    if (selected != state.selectedBasin) {
      cubit.selectBasin(selected);
    }
  }

  Future<void> _openFileStatus(final HomeCubit cubit) async {
    await context.pushNamed(Routes.fileStatus);
    if (mounted) cubit.refreshData();
  }

  Future<void> _openCityPicker(final HomeCubit cubit) async {
    final CitySnapshot? snapshot =
        await context.pushNamed<CitySnapshot>(Routes.cityPicker);
    if (snapshot != null && mounted) {
      cubit.loadFromDownloadedCity(snapshot);
    }
  }

  /// Runs once right after a file finishes loading: confirms اسم الجمعية
  /// first (if needed), then opens the basin filter (if there's more than
  /// one basin) — sequential, never both sheets at once.
  Future<void> _onFileLoaded(final HomeCubit cubit) async {
    if (cubit.state.needsAssociationConfirm) {
      final String confirmed = await showAssociationNameSheet(
        context,
        derivedName: cubit.state.associationNameDraft ?? '',
      );
      if (mounted) await cubit.confirmAssociationName(confirmed);
    }
    if (!mounted) return;
    if (cubit.state.availableBasins.length > 1) {
      await _openBasinFilter(cubit);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final HomeCubit cubit = context.read<HomeCubit>();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: BlocConsumer<HomeCubit, HomeState>(
          listenWhen: (final HomeState previous, final HomeState current) =>
              current.status == HomeStatus.loaded &&
              previous.status != HomeStatus.loaded,
          listener: (final BuildContext context, final HomeState state) {
            _onFileLoaded(cubit);
          },
          builder: (final BuildContext context, final HomeState state) {
            return Column(
              children: <Widget>[
                HomeTopBar(
                  onSettings: () => showSettingsSheet(context),
                  onHistory: _openHistory,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: KeyedSubtree(
                      key: ValueKey<HomeStatus>(state.status),
                      child: switch (state.status) {
                        HomeStatus.loading => const _LoadingBody(),
                        HomeStatus.noFile => EmptyBody(
                            onPickFile: () => _openCityPicker(cubit),
                          ),
                        HomeStatus.error => ErrorBody(
                            state: state,
                            onPickFile: cubit.pickFile,
                          ),
                        HomeStatus.loaded => _LoadedBody(
                            state: state,
                            controller: _controller,
                            cubit: cubit,
                            onQueryChanged: (final String q) =>
                                _onQueryChanged(q, cubit),
                            onOpenBasinFilter: () => _openBasinFilter(cubit),
                            onOpenFileStatus: () => _openFileStatus(cubit),
                            onToggleVoice: _voiceService == null
                                ? null
                                : () => _toggleVoiceSearch(cubit),
                            isListening: _isListening,
                          ),
                      },
                    ),
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

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(final BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary200),
    ).animate().fadeIn(duration: 200.ms);
  }
}

/// Search bar (and the file-info card above it) stay pinned at the top —
/// only the results list below scrolls — so the user never has to scroll
/// up just to search again.
class _LoadedBody extends StatefulWidget {
  const _LoadedBody({
    required this.state,
    required this.controller,
    required this.cubit,
    required this.onQueryChanged,
    required this.onOpenBasinFilter,
    required this.onOpenFileStatus,
    required this.onToggleVoice,
    required this.isListening,
  });

  final HomeState state;
  final TextEditingController controller;
  final HomeCubit cubit;
  final void Function(String query) onQueryChanged;
  final VoidCallback onOpenBasinFilter;
  final VoidCallback onOpenFileStatus;
  final VoidCallback? onToggleVoice;
  final bool isListening;

  @override
  State<_LoadedBody> createState() => _LoadedBodyState();
}

class _LoadedBodyState extends State<_LoadedBody> {
  void _openDetail(final BuildContext context, final SearchResult result) {
    final HoldingsRepository repository = getIt<HoldingsRepository>();
    context.pushNamed(
      Routes.holdingDetail,
      arguments: repository.parcelsForHolding(result.holdingId),
    );
  }

  Future<void> _openAddPerson(final BuildContext context) async {
    final bool? added = await context.pushNamed<bool>(
      Routes.addRecord,
      arguments: const AddRecordArgs(
        initialParcel: Parcel(holdingId: ''),
      ),
    );
    if (added == true && context.mounted) {
      widget.cubit.refreshData();
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    final List<Widget> suffixButtons = <Widget>[
      if (widget.onToggleVoice != null)
        IconButton(
          icon: Icon(
            widget.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
            color: widget.isListening
                ? AppColors.primary200
                : colors.iconSecondary,
          ),
          tooltip: 'holdings.search.voice'.tr(),
          onPressed: widget.onToggleVoice,
        ),
      if (widget.controller.text.isNotEmpty)
        IconButton(
          icon: Icon(Icons.close_rounded, color: colors.iconSecondary),
          onPressed: () {
            widget.controller.clear();
            widget.onQueryChanged('');
          },
        ),
    ];
    final Widget? suffixIcon = suffixButtons.isEmpty
        ? null
        : Row(mainAxisSize: MainAxisSize.min, children: suffixButtons);

    return LayoutBuilder(
      builder: (final BuildContext context, final BoxConstraints constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double horizontalPadding = isTablet ? rw(64) : rw(16);

        return Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  verticalSpacing(8),
                  if (widget.state.isCityDataStale) ...[
                    CityStaleBanner(onRefresh: widget.cubit.refreshActiveCity),
                    verticalSpacing(8),
                  ],
                  FileInfoCard(
                    holdingCount: widget.state.holdingCount,
                    selectedBasin: widget.state.selectedBasin,
                    hasBasins: widget.state.availableBasins.isNotEmpty,
                    onChangeFile: widget.cubit.changeFile,
                    onOpenBasinFilter: widget.onOpenBasinFilter,
                    onOpenFileStatus: widget.onOpenFileStatus,
                  ),
                  verticalSpacing(16),
                  CustomTextForm(
                    hintText: 'holdings.search.hint'.tr(),
                    controller: widget.controller,
                    isRTL: true,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: colors.iconSecondary,
                    ),
                    suffixIcon: suffixIcon,
                    onChanged: widget.onQueryChanged,
                  ),
                  verticalSpacing(8),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: RecommendationList(
                  query: widget.state.query,
                  results: widget.state.results,
                  onSelect: (final SearchResult result) =>
                      _openDetail(context, result),
                  onAddNew: () => _openAddPerson(context),
                ),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 250.ms);
      },
    );
  }
}
