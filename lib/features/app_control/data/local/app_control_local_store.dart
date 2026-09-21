import '../../../../core/storage/key_value_store.dart';
import '../model/app_control.dart';

class AppControlLocalStore {
  const AppControlLocalStore(this._store);

  static const _blockedKey = 'app_control.is_blocked';
  static const _arKey = 'app_control.message_ar';
  static const _enKey = 'app_control.message_en';

  final KeyValueStore _store;


  Future<AppControl?> read() async {
    final String? blockedValue = await _store.getString(_blockedKey);
    if (blockedValue == null) return null;
    return AppControl(
      isBlocked: blockedValue == 'true',
      messageAr: await _store.getString(_arKey) ?? AppControl.open.messageAr,
      messageEn: await _store.getString(_enKey) ?? AppControl.open.messageEn,
    );
  }

  Future<void> save(final AppControl value) async {
    await _store.setString(_blockedKey, value.isBlocked.toString());
    await _store.setString(_arKey, value.messageAr);
    await _store.setString(_enKey, value.messageEn);
  }
}
