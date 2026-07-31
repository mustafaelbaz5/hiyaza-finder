import 'package:equatable/equatable.dart';

import '../../domain/entities/city.dart';

enum CityPickerStatus { loading, loaded, downloading, error }

class CityPickerState extends Equatable {
  const CityPickerState({
    required this.status,
    this.cities = const <City>[],
    this.errorMessage,
  });

  factory CityPickerState.initial() =>
      const CityPickerState(status: CityPickerStatus.loading);

  final CityPickerStatus status;
  final List<City> cities;
  final String? errorMessage;

  CityPickerState copyWith({
    final CityPickerStatus? status,
    final List<City>? cities,
    final String? errorMessage,
  }) {
    return CityPickerState(
      status: status ?? this.status,
      cities: cities ?? this.cities,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, cities, errorMessage];
}
