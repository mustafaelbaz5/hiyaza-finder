import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../core/router/routes.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
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

/// Search-and-add bottom sheet for one Jazla — reuses the same
/// search-scoring logic as the home search (`JazlaSearchService`), but
/// returns parcel-level results. A free parcel's "+" opens Quick View; a
/// locked one shows which Jazla already has it and isn't addable. Also
/// offers the existing add-person/add-parcel-for-existing-person flows,
/// auto-adding whatever they return to this Jazla.
class JazlaAddParcelSheet extends StatelessWidget {
  const JazlaAddParcelSheet({super.key, required this.jazlaId});

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
    final JazlaAddParcelCubit cubit = context.read<JazlaAddParcelCubit>();
    final bool? added = await showJazlaQuickViewSheet(
      context,
      parcel: parcel,
      jazlaId: widget.jazlaId,
    );
    if (added == true && mounted) {
      cubit.search(cubit.state.query);
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
    if (created != null && mounted) {
      await cubit.onExternalParcelCreated(created);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: rh(640)),
        padding: EdgeInsets.fromLTRB(rw(20), rh(16), rw(20), rh(20)),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(rr(20))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'jazla.add_sheet.title'.tr(),
                    style: AppTextStyles.font18Bold.copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.right,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.iconSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            verticalSpacing(8),
            JazlaSearchBar(
              controller: _controller,
              onChanged: (final String q) => context.read<JazlaAddParcelCubit>().search(q),
            ),
            verticalSpacing(12),
            Flexible(
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
                    shrinkWrap: true,
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
            verticalSpacing(12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addNewPerson,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: Text(
                      'jazla.add_sheet.add_new_person'.tr(),
                      style: AppTextStyles.font14SemiBold.copyWith(color: AppColors.primary200),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
