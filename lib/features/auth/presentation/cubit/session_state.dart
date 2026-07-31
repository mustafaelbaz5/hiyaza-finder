import 'package:equatable/equatable.dart';

import '../../domain/entities/app_user.dart';

enum SessionStatus { unauthenticated, authenticating, authenticated }

class SessionState extends Equatable {
  const SessionState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  factory SessionState.unauthenticated() =>
      const SessionState(status: SessionStatus.unauthenticated);

  factory SessionState.authenticated(final AppUser user) =>
      SessionState(status: SessionStatus.authenticated, user: user);

  final SessionStatus status;
  final AppUser? user;
  final String? errorMessage;

  bool get isAuthenticated => status == SessionStatus.authenticated;

  SessionState copyWith({
    final SessionStatus? status,
    final AppUser? user,
    final String? errorMessage,
  }) {
    return SessionState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, user?.id, errorMessage];
}
