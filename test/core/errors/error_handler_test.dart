import 'dart:async' as async_lib;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/errors/error_handler.dart';
import 'package:hiyaza_finder/core/errors/exceptions.dart';
import 'package:hiyaza_finder/core/errors/failure.dart';

/// `REFACTOR_ROADMAP.md` Phase 21: `ErrorHandler` previously let any raw
/// [SocketException]/[HandshakeException]/`dart:async`'s
/// [async_lib.TimeoutException] fall through to a generic [ServerException]
/// with no useful message — exactly why the app always blamed "check your
/// connection" or showed a meaningless server error regardless of what
/// actually failed. Verifies these are now classified into the right
/// [AppException] subtype instead.
void main() {
  group('handleException', () {
    test('a SocketException throws NetworkException', () {
      expect(
        () => ErrorHandler.handleException(
          const SocketException('Failed host lookup'),
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a HandshakeException throws NetworkException', () {
      expect(
        () => ErrorHandler.handleException(
          const HandshakeException('TLS handshake failed'),
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test("dart:async's TimeoutException throws this app's TimeoutException",
        () {
      expect(
        () => ErrorHandler.handleException(
          async_lib.TimeoutException('Future not completed'),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('an already-typed AppException is rethrown unchanged', () {
      final ConflictException original = ConflictException(message: 'dup');
      expect(
        () => ErrorHandler.handleException(original),
        throwsA(same(original)),
      );
    });

    test('a genuinely unrecognized error still falls back to ServerException',
        () {
      expect(
        () => ErrorHandler.handleException('some opaque string error'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('handleFailure', () {
    test('a SocketException converts to NetworkFailure', () {
      final failure = ErrorHandler.handleFailure(
        const SocketException('Failed host lookup'),
      );
      expect(failure, isA<NetworkFailure>());
    });

    test("dart:async's TimeoutException converts to TimeoutFailure", () {
      final failure = ErrorHandler.handleFailure(
        async_lib.TimeoutException('Future not completed'),
      );
      expect(failure, isA<TimeoutFailure>());
    });
  });
}
