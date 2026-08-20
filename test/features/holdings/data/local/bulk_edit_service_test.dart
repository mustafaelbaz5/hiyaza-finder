import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/data/model/bulk_editable_field.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';
import 'package:hiyaza_finder/features/holdings/data/local/bulk_edit_service.dart';

void main() {
  const BulkEditService service = BulkEditService();

  final List<Parcel> parcels = <Parcel>[
    const Parcel(id: '1', holdingId: '101', basinName: 'البشيط'),
    const Parcel(id: '2', holdingId: '102', basinName: 'البشيط'),
    const Parcel(id: '3', holdingId: '103', basinName: 'السواخ'),
  ];

  test('applies a text field to every parcel when basin is null', () {
    final BulkEditResult result = service.apply(
      parcels,
      field: BulkEditableField.cropType,
      value: 'قمح',
    );

    expect(result.changedCount, 3);
    expect(
      result.parcels.every((final Parcel p) => p.cropType == 'قمح'),
      isTrue,
    );
  });

  test('scopes the change to the given basin only', () {
    final BulkEditResult result = service.apply(
      parcels,
      field: BulkEditableField.notes,
      value: 'وضع يد',
      basin: 'البشيط',
    );

    expect(result.changedCount, 2);
    expect(
      result.parcels
          .where((final Parcel p) => p.basinName == 'البشيط')
          .every((final Parcel p) => p.notes == 'وضع يد'),
      isTrue,
    );
    expect(
      result.parcels.firstWhere((final Parcel p) => p.basinName == 'السواخ').notes,
      isNull,
    );
  });

  test('applies the boolean وراثة field', () {
    final BulkEditResult result = service.apply(
      parcels,
      field: BulkEditableField.isInheritance,
      value: true,
    );

    expect(
      result.parcels.every((final Parcel p) => p.isInheritance),
      isTrue,
    );
  });

  test('a value can clear a nullable field', () {
    final List<Parcel> withCrop =
        parcels.map((final Parcel p) => p.copyWith(cropType: 'قمح')).toList();

    final BulkEditResult result = service.apply(
      withCrop,
      field: BulkEditableField.cropType,
      value: null,
    );

    expect(
      result.parcels.every((final Parcel p) => p.cropType == null),
      isTrue,
    );
  });
}
