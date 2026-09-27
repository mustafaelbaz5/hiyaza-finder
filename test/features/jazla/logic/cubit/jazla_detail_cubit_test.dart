import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:hiyaza_finder/features/jazla/data/model/jazla.dart';
import 'package:hiyaza_finder/features/jazla/data/repo/jazla_repo.dart';
import 'package:hiyaza_finder/features/jazla/logic/cubit/jazla_detail_cubit.dart';
import 'package:hiyaza_finder/features/jazla/logic/cubit/jazla_detail_state.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/repo/holdings_reader.dart';

class _FakeJazlaRepo extends Fake implements JazlaRepo {
  _FakeJazlaRepo(this.jazlas);

  final List<Jazla> jazlas;

  @override
  Future<List<Jazla>> getAll(final String cityId) async => jazlas;

  @override
  Future<void> addParcel(
    final String jazlaId,
    final String parcelId,
    final String cityId,
  ) async {}

  @override
  Future<void> removeParcel(
    final String jazlaId,
    final String parcelId,
    final String cityId,
  ) async {}
}

class _FakeParcelCatalogReader extends Fake implements ParcelCatalogReader {
  _FakeParcelCatalogReader(this.values);

  final List<Parcel> values;

  @override
  List<Parcel> get parcels => values;
}

class _DelayedDeleteJazlaRepo extends _FakeJazlaRepo {
  _DelayedDeleteJazlaRepo(super.jazlas);

  final Completer<void> deleteCompleter = Completer<void>();

  @override
  Future<void> delete(final String jazlaId, final String cityId) {
    return deleteCompleter.future;
  }
}

void main() {
  const String cityId = 'city';
  const String jazlaId = 'jazla';
  final DateTime createdAt = DateTime(2026, 9, 27);
  const Parcel first = Parcel(id: 'p1', holdingId: '1');
  const Parcel second = Parcel(id: 'p2', holdingId: '2');
  final Jazla jazla = Jazla(
    id: jazlaId,
    cityId: cityId,
    name: 'الاختبار',
    parcelIds: const <String>['p1'],
    createdAt: createdAt,
  );

  late _FakeJazlaRepo repo;
  late _FakeParcelCatalogReader reader;
  late JazlaDetailCubit cubit;

  setUp(() {
    repo = _FakeJazlaRepo(<Jazla>[jazla]);
    reader = _FakeParcelCatalogReader(<Parcel>[first, second]);
    cubit = JazlaDetailCubit(repo, reader, jazlaId, cityId);
  });

  tearDown(() => cubit.close());

  // Regression: the Jazla UI previously required leaving and reopening the
  // screen before a just-added parcel appeared.
  test('adding a parcel immediately updates its visible Jazla state', () async {
    await cubit.load();

    final Future<bool> completion = cubit.addParcel(second);

    expect(cubit.state.status, JazlaDetailStatus.loaded);
    expect(cubit.state.jazla?.parcelIds, <String>['p1', 'p2']);
    expect(cubit.state.parcels, <Parcel>[first, second]);
    expect(cubit.state.isParcelPending(second.id), isTrue);
    expect(await completion, isTrue);
    expect(cubit.state.isParcelPending(second.id), isFalse);
  });

  test('removing a parcel immediately updates its visible Jazla state',
      () async {
    await cubit.load();

    final Future<bool> completion = cubit.removeParcel(first.id);

    expect(cubit.state.jazla?.parcelIds, isEmpty);
    expect(cubit.state.parcels, isEmpty);
    expect(cubit.state.isParcelPending(first.id), isTrue);
    expect(await completion, isTrue);
    expect(cubit.state.isParcelPending(first.id), isFalse);
  });

  // Regression: dismissing the detail screen while delete was in-flight used
  // to throw "Cannot emit new states after calling close".
  test(
      'deleting after the detail screen closes does not emit to a closed cubit',
      () async {
    await cubit.close();
    final _DelayedDeleteJazlaRepo delayedRepo =
        _DelayedDeleteJazlaRepo(<Jazla>[jazla]);
    cubit = JazlaDetailCubit(delayedRepo, reader, jazlaId, cityId);

    final Future<void> deletion = cubit.deleteJazla();
    await cubit.close();
    delayedRepo.deleteCompleter.complete();

    await deletion;
  });
}
