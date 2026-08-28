import 'dart:async' as async_lib;
import 'dart:io';

import 'failure.dart';

import 'exceptions.dart';

class ErrorHandler {
  /// Call this in your data sources — throws AppException
  static Never handleException(final dynamic error) {
    if (error is AppException) throw error;

    final AppException? connectivity = _classifyConnectivityError(error);
    if (connectivity != null) throw connectivity;

    throw ServerException(message: error?.toString() ?? 'Unknown error.');
  }

  /// Call this in your repositories — converts exception to Failure
  static Failure handleFailure(final dynamic error) {
    final exception = error is AppException ? error : _toException(error);
    return _toFailure(exception);
  }

  static AppException _toException(final dynamic error) {
    final AppException? connectivity = _classifyConnectivityError(error);
    if (connectivity != null) return connectivity;
    return ServerException(message: error?.toString() ?? 'Unknown error.');
  }

  /// Distinguishes "the device genuinely couldn't reach the server at all"
  /// from a real server-side rejection — a raw [SocketException] (no route/
  /// DNS failure) or [HandshakeException] (TLS handshake never completed)
  /// only ever happens when the request never got a response, which is
  /// exactly what "check your internet connection" should mean. The
  /// `http.ClientException` thrown by the `http` package (connection
  /// refused/reset) surfaces the same way but is matched by its runtime
  /// type name instead of an import, so a future `http` major-version bump
  /// can't silently break this classification.
  /// `.timeout()` calls throw `dart:async`'s [async_lib.TimeoutException]
  /// (not this app's own [TimeoutException] in `exceptions.dart` — same
  /// name, different type, hence the aliased import) when the server took
  /// too long to respond — also a connectivity-shaped failure from the
  /// user's point of view, not a server rejection. Without any of this,
  /// every one of these fell through to a generic [ServerException] with no
  /// useful `message`, which is exactly why "server error"/"check your
  /// connection" messages showed up regardless of what actually failed
  /// (`REFACTOR_ROADMAP.md` Phase 21).
  static AppException? _classifyConnectivityError(final dynamic error) {
    if (error is SocketException ||
        error is HandshakeException ||
        error.runtimeType.toString() == 'ClientException') {
      return NetworkException();
    }
    if (error is async_lib.TimeoutException) {
      return TimeoutException();
    }
    return null;
  }

  static Failure _toFailure(final AppException e) {
    if (e is UnauthorizedException) {
      return UnauthorizedFailure(message: e.message);
    }
    if (e is ForbiddenException) return ForbiddenFailure(message: e.message);
    if (e is NotFoundException) return NotFoundFailure(message: e.message);
    if (e is ValidationException) {
      return ValidationFailure(message: e.message, errors: e.errors);
    }
    if (e is ConflictException) return ConflictFailure(message: e.message);
    if (e is NetworkException) return NetworkFailure(message: e.message);
    if (e is TimeoutException) return TimeoutFailure(message: e.message);
    if (e is TooManyRequestsException) {
      return TooManyRequestsFailure(message: e.message);
    }
    if (e is CacheException) return CacheFailure(message: e.message);
    if (e is ServerException) {
      return ServerFailure(message: e.message, code: e.statusCode);
    }
    return const UnknownFailure();
  }
}
