import 'package:flutter/material.dart';

import '../../../utils/extensions/context_ext.dart';

/// Standard compact icon action used in app bars and sheets.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isSelected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isSelected;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final Color foreground = onPressed == null
        ? colors.textDisabled
        : isSelected
            ? colors.textInverse
            : colors.iconPrimary;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        child: Material(
          color: isSelected
              ? Theme.of(context).primaryColor
              : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(icon, color: foreground, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}
