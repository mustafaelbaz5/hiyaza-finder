import 'package:equatable/equatable.dart';

import '../../data/model/jazla_transfer_bundle.dart';

enum JazlaImportStatus { idle, reading, preview, importing, success, error }

class JazlaImportState extends Equatable {
  const JazlaImportState({
    required this.status,
    this.bundle,
    this.hasConflict = false,
    this.errorMessage,
  });

  const JazlaImportState.initial() : this(status: JazlaImportStatus.idle);

  final JazlaImportStatus status;
  final JazlaTransferBundle? bundle;
  final bool hasConflict;
  final String? errorMessage;

  JazlaImportState copyWith({
    final JazlaImportStatus? status,
    final JazlaTransferBundle? bundle,
    final bool? hasConflict,
    final String? errorMessage,
  }) =>
      JazlaImportState(
        status: status ?? this.status,
        bundle: bundle ?? this.bundle,
        hasConflict: hasConflict ?? this.hasConflict,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props =>
      <Object?>[status, bundle, hasConflict, errorMessage];
}
