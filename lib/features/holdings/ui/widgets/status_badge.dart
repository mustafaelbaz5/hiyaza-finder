import 'package:flutter/material.dart';

import '../../../../core/themes/app_text_styles.dart';

/// A small tinted pill used for status markers above a card's fields — e.g.
/// the "edited"/"new / pending sync" markers on [ParcelDetailCard] and the
/// reviewed indicator on [RecommendationTile]. Lifted out of
/// `parcel_detail_card.dart`'s originally-private `_StatusBadge` once it was
/// needed in a second file.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.font12Bold.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
