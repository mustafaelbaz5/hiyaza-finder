import 'package:get_it/get_it.dart';

import '../networking/connection_quality_service.dart';
import 'modules/cities_module.dart';
import 'modules/core_module.dart';
import 'modules/crop_type_module.dart';
import 'modules/holdings_module.dart';

final GetIt getIt = GetIt.instance;

Future<void> setUpDependencies() async {
  await registerCoreModule(getIt);
  registerHoldingsModule(getIt);
  registerCitiesModule(getIt);
  registerCropTypeModule(getIt);

  // Starts polling immediately so the top-bar connectivity badge
  // (`HomeTopBar`) has a real classification on the very first frame,
  // instead of waiting for the first screen that happens to touch it.
  getIt<ConnectionQualityService>().start();
}
