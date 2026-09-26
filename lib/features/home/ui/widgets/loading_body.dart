import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import 'package:hiyaza_finder/features/parcel_search/data/local/holding_search_service.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/repo/holdings_reader.dart';
import 'package:hiyaza_finder/features/parcel_search/logic/cubit/parcel_search_cubit.dart';
import 'package:hiyaza_finder/features/parcel_search/logic/cubit/parcel_search_state.dart';
import 'package:hiyaza_finder/features/parcel_add/data/model/add_record_args.dart';
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
  const LoadedBody({super.key, required this.reader});

  final ParcelCatalogReader reader;

  @override
  State<LoadedBody> createState() => LoadedBodyState();
}

class LoadedBodyState extends State<LoadedBody> {
  Future<void> _openDetail(
    final BuildContext context,
    final SearchResult result,
  ) async {
    await context.pushNamed(
      Routes.holdingDetail,
      arguments: widget.reader.parcelsForHolding(result.groupKey),
    );
  }

  Future<void> _openAddPerson(final BuildContext context) async {
    await context.pushNamed<Parcel?>(
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
    // A successful add publishes an immutable repository snapshot. The
    // search Cubit is already subscribed, so no screen-wide manual refresh
    // is needed on return.
  }

  @override
  Widget build(final BuildContext context) {
    return BlocBuilder<ParcelSearchCubit, ParcelSearchState>(
      builder: (final BuildContext context, final ParcelSearchState state) =>
          LayoutBuilder(
        builder:
            (final BuildContext context, final BoxConstraints constraints) {
          final bool isTablet = constraints.maxWidth >= 600;
          final double horizontalPadding = isTablet ? rw(64) : rw(16);

          return Stack(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: state.query.trim().isNotEmpty
                    ? RecommendationList(
                        query: state.query,
                        results: state.results,
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
          );
        },
      ),
    );
  }
}
