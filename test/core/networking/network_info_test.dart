import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/networking/network_info.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

/// Queues canned results per call — mirrors
/// `InternetConnectionChecker.hasConnection`'s shape without hitting a real
/// network, so tests can simulate "the first probe times out, the retry
/// succeeds" deterministically.
class _ScriptedConnectionChecker implements InternetConnectionChecker {
  _ScriptedConnectionChecker(this._results);

  final List<bool> _results;
  int callCount = 0;

  @override
  Future<bool> get hasConnection async {
    callCount++;
    return _results.removeAt(0);
  }

  @override
  Stream<InternetConnectionStatus> get onStatusChange => const Stream.empty();

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  test('isConnected returns true immediately when the first probe succeeds '
      '— no retry needed', () async {
    final _ScriptedConnectionChecker checker =
        _ScriptedConnectionChecker(<bool>[true]);
    final NetworkInfoImpl networkInfo = NetworkInfoImpl(checker);

    expect(await networkInfo.isConnected, isTrue);
    expect(checker.callCount, 1);
  });

  test(
      'isConnected retries once and returns true when the first probe fails '
      'but the retry succeeds — a single transient timeout must not be '
      'reported as offline', () async {
    final _ScriptedConnectionChecker checker =
        _ScriptedConnectionChecker(<bool>[false, true]);
    final NetworkInfoImpl networkInfo = NetworkInfoImpl(checker);

    expect(await networkInfo.isConnected, isTrue);
    expect(checker.callCount, 2);
  });

  test('isConnected returns false only after both the initial probe and the '
      'retry fail', () async {
    final _ScriptedConnectionChecker checker =
        _ScriptedConnectionChecker(<bool>[false, false]);
    final NetworkInfoImpl networkInfo = NetworkInfoImpl(checker);

    expect(await networkInfo.isConnected, isFalse);
    expect(checker.callCount, 2);
  });
}
