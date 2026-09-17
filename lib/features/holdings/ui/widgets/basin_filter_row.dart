import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/spacing.dart';

import 'basin_chip.dart';

class BasinFilterRow extends StatelessWidget {
  const BasinFilterRow({
    super.key,
    required this.basins,
    required this.selected,
    required this.onChanged,
  });

  final List<String> basins;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(final BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        children: [
          BasinChip(
            label: 'cities.tools.missing_holding_id.filter_all_basins'.tr(),
            isSelected: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final String basin in basins) ...[
            horizontalSpacing(8),
            BasinChip(
              label: basin,
              isSelected: selected == basin,
              onTap: () => onChanged(basin),
            ),
          ],
        ],
      ),
    );
  }
}
