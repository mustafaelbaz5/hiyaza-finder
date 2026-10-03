import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import 'jazla_parcel_tile.dart';

class ParcelsTab extends StatelessWidget {
  const ParcelsTab({
    super.key,
    required this.parcels,
    required this.onReorder,
    required this.onTapParcel,
    required this.onRemoveParcel,
  });

  final List<Parcel> parcels;
  final void Function(List<String> newOrderIds) onReorder;
  final void Function(Parcel parcel) onTapParcel;
  final void Function(Parcel parcel) onRemoveParcel;

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
            onRemove: () => onRemoveParcel(parcel),
          ),
        );
      },
    );
  }
}
