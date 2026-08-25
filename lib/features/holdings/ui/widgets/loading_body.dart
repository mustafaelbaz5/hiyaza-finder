import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../data/local/holding_search_service.dart';
import '../../data/model/parcel.dart';
import '../../data/repo/holdings_repository.dart';
import '../../logic/cubit/home_cubit.dart';
import '../../logic/cubit/home_state.dart';
import '../add_record_screen.dart';
import 'home_empty_state.dart';
import 'recommendation_list.dart';

class LoadingBody extends StatelessWidget {
  const LoadingBody({super.key});

  @override
  Widget build(final BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary200),
    ).animate().fadeIn(duration: 200.ms);
  }
}

/// Home's results area (UI/UX Updates prompt "Change 5" moved the search
/// bar itself out into its own elevated card in `HomeScreen`, above this
/// widget — this only renders what's below it: [RecommendationList]'s
/// search results while [HomeState.query] is non-empty, and
/// [HomeEmptyState] otherwise). There is no flat, unfiltered city-wide list
/// here at all (basin grouping/progress lives on its own [BasinsPage]).
class LoadedBody extends StatefulWidget {
  const LoadedBody({
    super.key,
    required this.state,
    required this.cubit,
  });

  final HomeState state;
  final HomeCubit cubit;

  @override
  State<LoadedBody> createState() => LoadedBodyState();
}

class LoadedBodyState extends State<LoadedBody> {
  Future<void> _openDetail(
    final BuildContext context,
    final SearchResult result,
  ) async {
    final HoldingsRepository repository = getIt<HoldingsRepository>();
    await context.pushNamed(
      Routes.holdingDetail,
      arguments: repository.parcelsForHolding(result.groupKey),
    );
    // Detail Screen mutates parcels directly on the repository (Copy ID's
    // completedAt write included) without going through this cubit, so the
    // search results held in state — and the "تم المراجعة" badge derived
    // from them — go stale unless re-derived on return.
    if (context.mounted) widget.cubit.refreshData();
  }

  Future<void> _openAddPerson(final BuildContext context) async {
    final bool? added = await context.pushNamed<bool>(
      Routes.addRecord,
      arguments: const AddRecordArgs(
        initialParcel: Parcel(
          // Left blank — رقم الحيازة is a required field
          // (`Parcel.hasRequiredFieldsFilled`) that must be explicitly
          // typed by the user.
          holdingId: '',
          landNumber: '0',
          holdingsCount: 1, // a brand-new person starts with one قطعة
        ),
      ),
    );
    if (added == true && context.mounted) {
      widget.cubit.refreshData();
    }
  }

  @override
  Widget build(final BuildContext context) {
    final bool isSearching = widget.state.query.trim().isNotEmpty;

    return LayoutBuilder(
      builder: (final BuildContext context, final BoxConstraints constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double horizontalPadding = isTablet ? rw(64) : rw(16);

        return Stack(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: isSearching
                  ? RecommendationList(
                      query: widget.state.query,
                      results: widget.state.results,
                      onSelect: (final SearchResult result) async =>
                          _openDetail(context, result),
                      onAddNew: () => _openAddPerson(context),
                    )
                  : const HomeEmptyState(),
            ),
            // Always-visible add-person entry point — previously only
            // reachable after typing a search that returned no results,
            // which meant a brand-new person could only be added by first
            // proving they weren't already in the data.
            PositionedDirectional(
              bottom: rh(20),
              end: rw(20),
              child: FloatingActionButton.extended(
                onPressed: () => _openAddPerson(context),
                backgroundColor: AppColors.primary200,
                foregroundColor: AppColors.white,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text('holdings.add.new_person_cta'.tr()),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 250.ms);
      },
    );
  }
}
