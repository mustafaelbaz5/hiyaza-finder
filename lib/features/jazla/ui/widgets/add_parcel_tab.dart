import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../../data/local/jazla_search_service.dart';
import '../../logic/cubit/jazla_add_parcel_cubit.dart';
import '../../logic/cubit/jazla_add_parcel_state.dart';
import 'jazla_parcel_result_tile.dart';
import 'jazla_search_bar.dart';

class AddParcelTab extends StatelessWidget {
  const AddParcelTab({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.onAddTap,
    required this.onEditTap,
    required this.onAddNewPerson,
    required this.onAddForPerson,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<Parcel> onAddTap;
  final ValueChanged<Parcel> onEditTap;
  final VoidCallback onAddNewPerson;
  final ValueChanged<Parcel> onAddForPerson;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: rw(16)),
          child: JazlaSearchBar(
            controller: searchController,
            focusNode: searchFocusNode,
            onChanged: (final String q) =>
                context.read<JazlaAddParcelCubit>().search(q),
          ),
        ),
        verticalSpacing(12),
        Expanded(
          child: BlocBuilder<JazlaAddParcelCubit, JazlaAddParcelState>(
            builder:
                (final BuildContext context, final JazlaAddParcelState state) {
              if (state.query.trim().isEmpty) {
                return const SizedBox.shrink();
              }
              if (state.results.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: rh(24)),
                  child: Column(
                    children: [
                      Text(
                        'jazla.add_sheet.no_results'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      verticalSpacing(12),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: rw(16)),
                        child: OutlinedButton.icon(
                          onPressed: onAddNewPerson,
                          icon: const Icon(Icons.person_add_alt_1_rounded,
                              size: 18),
                          label: Text(
                            'jazla.add_sheet.add_new_person'.tr(),
                            style: AppTextStyles.font14SemiBold
                                .copyWith(color: AppColors.primary200),
                          ),
                        ),
                      ),
                    ],
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
                    onAddTap: () => onAddTap(result.parcel),
                    onEditTap: () => onEditTap(result.parcel),
                    onAddForPerson: () => onAddForPerson(result.parcel),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
