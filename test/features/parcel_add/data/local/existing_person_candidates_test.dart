import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/parcel_add/data/local/existing_person_candidates.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';

void main() {
  const Parcel firstPersonFirstParcel = Parcel(
    id: 'p1',
    personId: 'person-1',
    holdingId: '42',
    holderName: 'أحمد علي',
    nationalId: '11111111111111',
  );
  const Parcel firstPersonSecondParcel = Parcel(
    id: 'p2',
    personId: 'person-1',
    holdingId: '42',
    holderName: 'أحمد علي',
    nationalId: '11111111111111',
  );
  const Parcel secondPersonParcel = Parcel(
    id: 'p3',
    personId: 'person-2',
    holdingId: '42',
    holderName: 'محمود حسن',
    nationalId: '22222222222222',
  );

  test('builds one candidate per person under the same holding number', () {
    final List<ExistingPersonCandidate> candidates =
        buildExistingPersonCandidates(
      matchingParcels: const <Parcel>[
        firstPersonFirstParcel,
        firstPersonSecondParcel,
        secondPersonParcel,
      ],
    );

    expect(candidates, hasLength(2));
    expect(candidates.first.holderName, 'أحمد علي');
    expect(candidates.first.nationalId, '11111111111111');
    expect(candidates.first.parcelCount, 2);
    expect(candidates.last.holderName, 'محمود حسن');
    expect(candidates.last.parcelCount, 1);
  });

  test('falls back to national ID when an imported person has no person ID',
      () {
    const Parcel firstImportedPerson = Parcel(
      id: 'import-1',
      holdingId: '77',
      holderName: 'فاطمة علي',
      nationalId: '33333333333333',
    );
    const Parcel secondImportedPerson = Parcel(
      id: 'import-2',
      holdingId: '77',
      holderName: 'منى حسن',
      nationalId: '44444444444444',
    );

    final List<ExistingPersonCandidate> candidates =
        buildExistingPersonCandidates(
      matchingParcels: const <Parcel>[
        firstImportedPerson,
        secondImportedPerson,
      ],
    );

    expect(candidates, hasLength(2));
    expect(candidates.first.groupKey, 'national:33333333333333');
    expect(candidates.last.groupKey, 'national:44444444444444');
  });
}
