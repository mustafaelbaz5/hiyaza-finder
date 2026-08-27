import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../core/router/routes.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/widgets/screen_header.dart';
import '../../holdings/data/model/parcel.dart';
import '../../holdings/data/repo/holdings_reader.dart';
import '../../holdings/data/repo/holdings_repository.dart';
import '../../holdings/ui/add_record_screen.dart';
import '../data/local/jazla_search_service.dart';
import '../data/repo/jazla_repo.dart';
import '../logic/cubit/jazla_add_parcel_cubit.dart';
import '../logic/cubit/jazla_add_parcel_state.dart';
import 'widgets/jazla_parcel_result_tile.dart';
import 'widgets/jazla_quick_view_sheet.dart';
import 'widgets/jazla_search_bar.dart';

/// Full-screen search-and-add flow for one Jazla (UI-only change — the
/// search/add logic is unchanged, only its container moved from a bottom
/// sheet to a dedicated screen): a modal bottom sheet's keyboard covered the
/// search bar and stacking a second sheet (Quick View) on top of this one
/// felt heavy. Reuses the same search-scoring logic as the home search
/// (`JazlaSearchService`), but returns parcel-level results. A free
/// parcel's "+" opens Quick View (still a compact bottom sheet — see
/// [showJazlaQuickViewSheet]); a locked one shows which Jazla already has
/// it and isn't addable. Also offers the existing add-person/
/// add-parcel-for-existing-person flows, auto-adding whatever they return
/// to this Jazla.
class JazlaAddParcelScreen extends StatelessWidget {
  const JazlaAddParcelScreen({super.key, required this.jazlaId});

  final String jazlaId;

  @override
  Widget build(final BuildContext context) {
    final String cityId = getIt<HoldingsRepository>().activeCityId ?? '';
    return BlocProvider<JazlaAddParcelCubit>(
      create: (final _) => JazlaAddParcelCubit(
        getIt<JazlaRepo>(),
        getIt<HoldingsReader>(),
        getIt<JazlaSearchService>(),
        jazlaId,
        cityId,
      ),
      child: _JazlaAddParcelView(jazlaId: jazlaId),
    );
  }
}

class _JazlaAddParcelView extends StatefulWidget {
  const _JazlaAddParcelView({required this.jazlaId});

  final String jazlaId;

  @override
  State<_JazlaAddParcelView> createState() => _JazlaAddParcelViewState();
}

class _JazlaAddParcelViewState extends State<_JazlaAddParcelView> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openQuickView(final Parcel parcel) async {
    final bool? added = await showJazlaQuickViewSheet(
      context,
      parcel: parcel,
      jazlaId: widget.jazlaId,
    );
    // Confirming Quick View is the end of this flow — return straight to
    // the Jazla Detail screen instead of staying on the search screen, per
    // the "Quick View confirm → back to Detail" requirement.
    if (added == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _addNewPerson() async {
    final JazlaAddParcelCubit cubit = context.read<JazlaAddParcelCubit>();
    final Parcel? created = await context.pushNamed<Parcel>(
      Routes.addRecord,
      arguments: const AddRecordArgs(
        initialParcel: Parcel(holdingId: '', landNumber: '0', holdingsCount: 1),
      ),
    );
    if (created == null || !mounted) return;
    await cubit.onExternalParcelCreated(created);
    // The new parcel is auto-added to this Jazla — return to Jazla Detail
    // rather than staying on the search screen, matching Quick View's
    // confirm-then-return-to-Detail behavior.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      backgroundColor: colors.background,
      // Full-screen (not a bottom sheet) so the keyboard never covers the
      // search bar, and the user has the whole viewport to work with —
      // resizes to keep the results list above the keyboard as it opens.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(title: 'jazla.add_sheet.title'.tr()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: rw(16)),
              child: JazlaSearchBar(
                controller: _controller,
                onChanged: (final String q) =>
                    context.read<JazlaAddParcelCubit>().search(q),
              ),
            ),
            verticalSpacing(12),
            Expanded(
              child: BlocBuilder<JazlaAddParcelCubit, JazlaAddParcelState>(
                builder: (final BuildContext context, final JazlaAddParcelState state) {
                  if (state.query.trim().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  if (state.results.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: rh(24)),
                      child: Text(
                        'jazla.add_sheet.no_results'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: rw(16)),
                    itemCount: state.results.length,
                    itemBuilder: (final BuildContext context, final int i) {
                      final ParcelSearchResult result = state.results[i];
                      return JazlaParcelResultTile(
                        result: result,
                        onAddTap: () => _openQuickView(result.parcel),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(rw(16), 0, rw(16), rh(16)),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addNewPerson,
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: Text(
                        'jazla.add_sheet.add_new_person'.tr(),
                        style: AppTextStyles.font14SemiBold
                            .copyWith(color: AppColors.primary200),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
