import 'package:get_it/get_it.dart';

import 'modules/auth_module.dart';
import 'modules/cities_module.dart';
import 'modules/core_module.dart';
import 'modules/holdings_module.dart';

final GetIt getIt = GetIt.instance;

Future<void> setUpDependencies() async {
  await registerCoreModule(getIt);
  registerAuthModule(getIt);
  registerHoldingsModule(getIt);
  registerCitiesModule(getIt);
}
