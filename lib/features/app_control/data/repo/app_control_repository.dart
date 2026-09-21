import '../model/app_control.dart';

abstract interface class AppControlRepository {
  Future<AppControl?> readCached();
  Future<void> saveCached(AppControl value);
  Future<AppControl> refresh();
}
