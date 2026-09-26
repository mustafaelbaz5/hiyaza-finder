import '../model/app_control.dart';

abstract interface class AppControlRepository {
  Future<AppControl?> readCached();
  Future<void> saveCached(final AppControl value);
  Future<AppControl> refresh();
}
