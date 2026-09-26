import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hiyaza_finder/core/utils/extensions/context_ext.dart';
import 'package:hiyaza_finder/core/utils/spacing.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';
import 'package:hiyaza_finder/features/jazla/ui/widgets/jazla_parcel_tile.dart';

class ParcelsTab extends StatelessWidget {
  const ParcelsTab({
    super.key,
    required this.parcels,
    required this.onReorder,
    required this.onTapParcel,
    required this.onLongPressParcel,
  });

  final List<Parcel> parcels;
  final void Function(List<String> newOrderIds) onReorder;
  final void Function(Parcel parcel) onTapParcel;
  final void Function(Parcel parcel) onLongPressParcel;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    if (parcels.isEmpty) {
      return Center(
        child: Text(
          'jazla.detail.empty'.tr(),
          style: TextStyle(color: colors.textSecondary),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(rw(16), 0, rw(16), rh(24)),
      itemCount: parcels.length,
      onReorderItem: (final int oldIndex, final int newIndex) {
        final List<String> ids = parcels.map((final Parcel p) => p.id).toList();
        final String moved = ids.removeAt(oldIndex);
        ids.insert(newIndex, moved);
        onReorder(ids);
      },
      itemBuilder: (final BuildContext context, final int i) {
        final Parcel parcel = parcels[i];
        return Padding(
          key: ValueKey<String>(parcel.id),
          padding: const EdgeInsets.only(bottom: 10),
          child: JazlaParcelTile(
            index: i + 1,
            parcel: parcel,
            onTap: () => onTapParcel(parcel),
            onLongPress: () => onLongPressParcel(parcel),
          ),
        );
      },
    );
  }
}
