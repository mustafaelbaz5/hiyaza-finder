import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hiyaza_finder/core/themes/app_text_styles.dart';
import 'package:hiyaza_finder/core/utils/extensions/context_ext.dart';
import 'package:hiyaza_finder/core/utils/spacing.dart';
import 'package:hiyaza_finder/core/widgets/ui/buttons/app_icon_button.dart';
import 'package:hiyaza_finder/features/jazla/data/model/jazla.dart';

class JazlaDetailAppBar extends StatelessWidget {
  const JazlaDetailAppBar({
    super.key,
    required this.jazla,
    required this.onActionsPressed,
  });

  final Jazla jazla;
  final VoidCallback onActionsPressed;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(rw(12), rh(8), rw(12), rh(12)),
      child: Row(
        children: [
          AppIconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.maybePop(context),
            icon: Icons.arrow_back_ios_rounded,
          ),
          horizontalSpacing(8),
          Expanded(
            child: Text(
              jazla.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style:
                  AppTextStyles.font18Bold.copyWith(color: colors.textPrimary),
            ),
          ),
          horizontalSpacing(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            child: Text(
              'jazla.parcel_count'.tr(
                namedArgs: <String, String>{
                  'count': jazla.parcelCount.toString()
                },
              ),
              style: AppTextStyles.font12Regular
                  .copyWith(color: colors.textSecondary),
            ),
          ),
          horizontalSpacing(4),
          AppIconButton(
            tooltip: 'jazla.actions.title'.tr(),
            onPressed: onActionsPressed,
            icon: Icons.tune_rounded,
          ),
        ],
      ),
    );
  }
}
