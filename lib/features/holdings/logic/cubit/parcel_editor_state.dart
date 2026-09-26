import 'package:equatable/equatable.dart';

import '../../data/model/parcel.dart';

enum ParcelEditorStatus { idle, saving, saved, failure }

class ParcelEditorState extends Equatable {
  const ParcelEditorState({
    this.status = ParcelEditorStatus.idle,
    this.parcel,
    this.error,
  });

  final ParcelEditorStatus status;
  final Parcel? parcel;
  final Object? error;

  ParcelEditorState copyWith({
    final ParcelEditorStatus? status,
    final Parcel? parcel,
    final Object? error,
  }) =>
      ParcelEditorState(
        status: status ?? this.status,
        parcel: parcel ?? this.parcel,
        error: error,
      );

  @override
  List<Object?> get props => <Object?>[status, parcel, error];
}
