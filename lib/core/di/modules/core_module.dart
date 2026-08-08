import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../../networking/network_info.dart';
import '../../service/secure_storage.dart';
import '../../service/voice_search_service.dart';
import '../../storage/key_value_store.dart';

/// Hosts [NetworkInfo] checks for reachability. Checks two well-known,
/// virtually-always-up public hosts — not the app's own Supabase domain.
///
/// A Phase 16 version of this pinged the bare Supabase domain
/// (`https://<project>.supabase.co`, no path) directly, reasoning that "can
/// this app reach its own backend" is more accurate than an arbitrary
/// public host. In practice that domain is Cloudflare-fronted with bot
/// management (`__cf_bm` cookie on every response) and returned a bare
/// `404` to a plain HEAD request — behavior an emulator's network stack
/// handled inconsistently, causing the app-launch "no internet" dialog to
/// fire even when the device was genuinely online and the rest of the app
/// could reach Supabase's actual REST API just fine. Reverted to checking
/// only these two hosts, which behave predictably everywhere. Any one
/// responding is enough (`requireAllAddressesToRespond` defaults to false).
List<AddressCheckOption> _connectivityCheckAddresses() {
  return <AddressCheckOption>[
    AddressCheckOption(uri: Uri.parse('https://one.one.one.one')),
    AddressCheckOption(uri: Uri.parse('https://dns.google')),
  ];
}

/// App-wide singletons that every feature module may depend on: network
/// status, secure/plain key-value storage, and cross-cutting services.
Future<void> registerCoreModule(final GetIt getIt) async {
  getIt.registerLazySingleton(
    () => InternetConnectionChecker.createInstance(
      addresses: _connectivityCheckAddresses(),
    ),
  );

  if (!getIt.isRegistered<SecureStorage>()) {
    getIt.registerLazySingleton<SecureStorage>(
      () => const SecureStorage(FlutterSecureStorage()),
    );
  }

  getIt.registerLazySingleton<KeyValueStore>(
    () => const SharedPreferencesKeyValueStore(),
  );

  getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(getIt()));

  getIt.registerLazySingleton<VoiceSearchService>(VoiceSearchService.new);
}
