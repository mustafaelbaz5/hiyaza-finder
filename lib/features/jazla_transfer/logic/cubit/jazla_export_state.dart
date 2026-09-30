import 'package:equatable/equatable.dart';

import '../../data/model/jazla_transfer_bundle.dart';

enum JazlaExportStatus { idle, exporting, success, error }

class JazlaExportState extends Equatable {
  const JazlaExportState({
    required this.status,
    this.bundle,
    this.errorMessage,
  });

  const JazlaExportState.initial() : this(status: JazlaExportStatus.idle);

  final JazlaExportStatus status;
  final JazlaTransferBundle? bundle;
  final String? errorMessage;

  JazlaExportState copyWith({
    final JazlaExportStatus? status,
    final JazlaTransferBundle? bundle,
    final String? errorMessage,
  }) =>
      JazlaExportState(
        status: status ?? this.status,
        bundle: bundle ?? this.bundle,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => <Object?>[status, bundle, errorMessage];
}
