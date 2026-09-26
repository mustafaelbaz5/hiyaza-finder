import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/di/dependency_injection.dart';
import '../../parcel_catalog/data/model/parcel.dart';
import '../../parcel_catalog/data/repo/parcel_catalog_repository.dart';
import '../../parcel_details/ui/widgets/parcel_detail_card.dart';

class JazlaReviewScreen extends StatefulWidget {
  const JazlaReviewScreen({
    super.key,
    required this.jazlaName,
    required this.parcels,
    required this.initialIndex,
  });

  final String jazlaName;
  final List<Parcel> parcels;
  final int initialIndex;

  @override
  State<JazlaReviewScreen> createState() => _JazlaReviewScreenState();
}

class _JazlaReviewScreenState extends State<JazlaReviewScreen> {
  late int _index = widget.initialIndex;
  late final List<Parcel> _parcels = List<Parcel>.of(widget.parcels);

  Parcel get _parcel => _parcels[_index];

  Future<void> _save(final Parcel updated) async {
    await getIt<ParcelCatalogRepository>().updateParcel(updated);
    if (mounted) setState(() => _parcels[_index] = updated);
  }

  void _move(final int delta) {
    final int next = _index + delta;
    if (next < 0 || next >= _parcels.length) return;
    setState(() => _index = next);
  }

  Future<void> _reopen() async {
    final Parcel? updated = await getIt<ParcelCatalogRepository>()
        .setParcelCompleted(_parcel.id, completed: false);
    if (updated != null && mounted) setState(() => _parcels[_index] = updated);
  }

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.jazlaName),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Text('${_index + 1} / ${_parcels.length}'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ParcelDetailCard(
              parcel: _parcel,
              onFieldChanged: (final Parcel value) => _save(value),
              onCompleted: (final Parcel value) =>
                  setState(() => _parcels[_index] = value),
              availableBasins: getIt<ParcelCatalogRepository>().availableBasins,
              parcelsForHolding:
                  getIt<ParcelCatalogRepository>().parcelsForHolding,
              setParcelCompleted:
                  getIt<ParcelCatalogRepository>().setParcelCompleted,
              onReopen: () => _reopen(),
              onRegenerate: (final String id) async {
                final Parcel? updated = await getIt<ParcelCatalogRepository>()
                    .regenerateLocalParcelId(id);
                if (updated != null && mounted) {
                  setState(() => _parcels[_index] = updated);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _index == 0 ? null : () => _move(-1),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text('jazla.review.previous'.tr()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        _index == _parcels.length - 1 ? null : () => _move(1),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text('jazla.review.next'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
