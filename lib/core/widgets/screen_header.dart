import 'package:flutter/material.dart';

import '../themes/app_text_styles.dart';
import '../utils/extensions/context_ext.dart';
import '../utils/spacing.dart';
import 'app_back_button.dart';

/// The standard "back button + title" top bar shared by every screen that
/// doesn't need anything more elaborate (a subtitle, a refresh action, an
/// inline banner) — those cases (e.g. `DetailScreen`, `AddRecordScreen`)
/// have their own dedicated header widget instead of stretching this one
/// with optional params for every screen's specific extra.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.onBack});

  final String title;

  /// Defaults to `Navigator.pop` (via [AppBackButton]'s own default) when
  /// omitted — pass this only when the back action needs to do something
  /// beyond a plain pop (e.g. a discard-confirmation check).
  final VoidCallback? onBack;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rw(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          verticalSpacing(16),
          Row(
            children: <Widget>[
              AppBackButton(onTap: onBack),
              horizontalSpacing(12),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.font20Bold.copyWith(
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          verticalSpacing(16),
        ],
      ),
    );
  }
}
