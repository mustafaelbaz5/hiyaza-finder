import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/networking/connection_quality_service.dart';
import 'package:hiyaza_finder/core/networking/network_info.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class _FakeNetworkInfo implements NetworkInfo {
  bool connected = true;
  Duration delay = Duration.zero;
  final StreamController<InternetConnectionStatus> _statusController =
      StreamController<InternetConnectionStatus>.broadcast();

  @override
  Future<bool> get isConnected async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return connected;
  }

  @override
  Stream<InternetConnectionStatus> get onStatusChange => _statusController.stream;

  void emitStatusChange(final InternetConnectionStatus status) =>
      _statusController.add(status);

  void dispose() => unawaited(_statusController.close());
}

void main() {
  late _FakeNetworkInfo networkInfo;
  late ConnectionQualityService service;

  tearDown(() {
    service.dispose();
    networkInfo.dispose();
  });

  test('classifies as strong when connected and the check is fast', () async {
    networkInfo = _FakeNetworkInfo()..connected = true;
    service = ConnectionQualityService(
      networkInfo,
      pollInterval: const Duration(minutes: 10),
      weakThreshold: const Duration(milliseconds: 500),
    );

    service.start();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // Starts already assuming `strong` (see ConnectionQualityService's
    // doc), so a check that confirms `strong` again produces no new stream
    // event — `current` is the only way to observe this case.
    expect(service.current, ConnectionQuality.strong);
  });

  test('classifies as offline when NetworkInfo reports disconnected', () async {
    networkInfo = _FakeNetworkInfo()..connected = false;
    service = ConnectionQualityService(
      networkInfo,
      pollInterval: const Duration(minutes: 10),
    );

    final Future<ConnectionQuality> next = service.onQualityChanged.first;
    service.start();

    expect(await next, ConnectionQuality.offline);
  });

  test('classifies as weak when connected but the check exceeds the '
      'weak threshold', () async {
    networkInfo = _FakeNetworkInfo()
      ..connected = true
      ..delay = const Duration(milliseconds: 50);
    service = ConnectionQualityService(
      networkInfo,
      pollInterval: const Duration(minutes: 10),
      weakThreshold: const Duration(milliseconds: 10),
    );

    final Future<ConnectionQuality> next = service.onQualityChanged.first;
    service.start();

    expect(await next, ConnectionQuality.weak);
  });

  test('does not emit again when the classification stays the same',
      () async {
    networkInfo = _FakeNetworkInfo()..connected = true;
    service = ConnectionQualityService(
      networkInfo,
      pollInterval: const Duration(minutes: 10),
    );

    final List<ConnectionQuality> emitted = <ConnectionQuality>[];
    final StreamSubscription<ConnectionQuality> sub =
        service.onQualityChanged.listen(emitted.add);

    service.start();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    networkInfo.emitStatusChange(InternetConnectionStatus.connected);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(emitted, isEmpty);
    await sub.cancel();
  });

  test('reacts to onStatusChange going offline before the next poll',
      () async {
    networkInfo = _FakeNetworkInfo()..connected = true;
    service = ConnectionQualityService(
      networkInfo,
      pollInterval: const Duration(minutes: 10),
    );
    service.start();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(service.current, ConnectionQuality.strong);

    networkInfo.connected = false;
    final Future<ConnectionQuality> next = service.onQualityChanged.first;
    networkInfo.emitStatusChange(InternetConnectionStatus.disconnected);

    expect(await next, ConnectionQuality.offline);
  });
}
