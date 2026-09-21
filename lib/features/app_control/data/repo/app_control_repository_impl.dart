import '../local/app_control_local_store.dart';
import '../model/app_control.dart';
import '../remote/app_control_remote_data_source.dart';
import 'app_control_repository.dart';

class AppControlRepositoryImpl implements AppControlRepository {
  const AppControlRepositoryImpl({required this.remote, required this.local});

  final AppControlRemoteDataSource remote;
  final AppControlLocalStore local;

  @override
  Future<AppControl?> readCached() => local.read();

  @override
  Future<void> saveCached(final AppControl value) => local.save(value);

  @override
  Future<AppControl> refresh() async {
    final AppControl value = await remote.read();
    await local.save(value);
    return value;
  }
}
