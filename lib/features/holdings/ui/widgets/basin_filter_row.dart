import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hiyaza_finder/core/utils/spacing.dart';
import 'package:hiyaza_finder/features/holdings/ui/missing_holding_id_screen.dart';

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
          _BasinChip(
            label: 'cities.tools.missing_holding_id.filter_all_basins'.tr(),
            isSelected: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final String basin in basins) ...[
            horizontalSpacing(8),
            _BasinChip(
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
