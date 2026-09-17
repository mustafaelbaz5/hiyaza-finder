import 'package:flutter/material.dart';
import '../../../../core/utils/extensions/context_ext.dart';

class TopBarIconButton extends StatelessWidget {
  const TopBarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colors.iconPrimary, size: 22),
        ),
      ),
    );
  }
}
