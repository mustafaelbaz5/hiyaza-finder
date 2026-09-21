import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../data/model/app_control.dart';

class AppBlockedScreen extends StatelessWidget {
  const AppBlockedScreen({required this.control, super.key});

  final AppControl control;

  @override
  Widget build(final BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.lock_clock_rounded, size: 72),
                  const SizedBox(height: 24),
                  Text(control.messageFor(context.locale.languageCode),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text('app_control.blocked_hint'.tr(),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
