import 'package:flutter/material.dart';
import 'package:hiyaza_finder/core/themes/app_colors.dart';

class TileIconButton extends StatelessWidget {
  const TileIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(final BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 17, color: AppColors.primary200),
        ),
      ),
    );
  }
}
