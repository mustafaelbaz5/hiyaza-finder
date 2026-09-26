import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';

void main() {
  test('zero parcels for one local person share a group', () {
    const Parcel first = Parcel(
      id: 'first',
      holdingId: '0',
      personId: 'person-1',
      holderName: 'أحمد',
    );
    const Parcel second = Parcel(
      id: 'second',
      holdingId: '0',
      personId: 'person-1',
      holderName: 'أحمد',
    );

    expect(first.groupKey, second.groupKey);
  });

  test('different zero people do not share a group', () {
    const Parcel first =
        Parcel(id: 'first', holdingId: '0', holderName: 'أحمد');
    const Parcel second =
        Parcel(id: 'second', holdingId: '0', holderName: 'محمد');

    expect(first.groupKey, isNot(second.groupKey));
  });
}
