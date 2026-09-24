import 'package:equatable/equatable.dart';

import '../../data/model/city.dart';

enum CityPickerStatus { loading, loaded, downloading, error }

class CityPickerState extends Equatable {
  const CityPickerState({
    required this.status,
    this.cities = const <City>[],
    this.errorMessage,
    this.cachedCityIds = const <String>{},
    this.isRefreshing = false,
  });

  factory CityPickerState.initial() =>
      const CityPickerState(status: CityPickerStatus.loading);

  final CityPickerStatus status;
  final List<City> cities;
  final String? errorMessage;
  final Set<String> cachedCityIds;
  final bool isRefreshing;

  CityPickerState copyWith({
    final CityPickerStatus? status,
    final List<City>? cities,
    final String? errorMessage,
    final Set<String>? cachedCityIds,
    final bool? isRefreshing,
  }) {
    return CityPickerState(
      status: status ?? this.status,
      cities: cities ?? this.cities,
      errorMessage: errorMessage,
      cachedCityIds: cachedCityIds ?? this.cachedCityIds,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[status, cities, errorMessage, cachedCityIds, isRefreshing];
}
