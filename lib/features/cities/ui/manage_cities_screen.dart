import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/ui/dialogs/app_dialogs.dart';
import '../data/model/cached_city_meta.dart';
import '../data/repo/city_repo.dart';
import 'widgets/cached_city_tile.dart';
import 'widgets/manage_cities_states.dart';

/// Lets the field worker see every city with data still on this device —
/// not just the active one — and free up space by deleting ones they're
/// done with. Deleting here only removes the local copy; the server's
/// data is untouched, and re-downloading is always available from the
/// city picker.
class ManageCitiesScreen extends StatefulWidget {
  const ManageCitiesScreen({super.key});

  @override
  State<ManageCitiesScreen> createState() => _ManageCitiesScreenState();
}

class _ManageCitiesScreenState extends State<ManageCitiesScreen> {
  final CityRepo _repository = getIt<CityRepo>();

  bool _isLoading = true;
  bool _hasError = false;
  List<CachedCityMeta> _cities = const <CachedCityMeta>[];
  String? _activeCityId;
  final Set<String> _deletingCityIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final List<CachedCityMeta> cities = await _repository.listCachedCities();
      final String? activeCityId =
          (await _repository.loadActiveCachedSnapshot())?.cityId;
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _activeCityId = activeCityId;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _confirmDelete(final CachedCityMeta city) async {
    final bool isActive = city.cityId == _activeCityId;
    await AppDialogs.showConfirm(
      context,
      message: isActive
          ? 'cities.manage.delete_confirm_active'.tr(
              namedArgs: {'name': city.cityName},
            )
          : 'cities.manage.delete_confirm'.tr(
              namedArgs: {'name': city.cityName},
            ),
      onConfirm: () => _delete(city),
    );
  }

  Future<void> _delete(final CachedCityMeta city) async {
    setState(() => _deletingCityIds.add(city.cityId));
    try {
      await _repository.deleteCachedCity(city.cityId);
      if (!mounted) return;
      setState(() {
        _cities = _cities
            .where((final CachedCityMeta c) => c.cityId != city.cityId)
            .toList();
        _deletingCityIds.remove(city.cityId);
        if (_activeCityId == city.cityId) _activeCityId = null;
      });
      if (mounted) {
        context.showSuccessSnackBar('cities.manage.deleted'.tr());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _deletingCityIds.remove(city.cityId));
      context.showErrorSnackBar('errors.unknown'.tr());
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(title: 'cities.manage.title'.tr()),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(final BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary200),
      );
    }

    if (_hasError) {
      return ManageCitiesErrorState(onRetry: _load);
    }

    if (_cities.isEmpty) {
      return const ManageCitiesEmptyState();
    }

    return ListView.builder(
      padding:
          EdgeInsets.symmetric(horizontal: rw(16)).copyWith(bottom: rh(24)),
      itemCount: _cities.length,
      itemBuilder: (final BuildContext context, final int i) {
        final CachedCityMeta city = _cities[i];
        return CachedCityTile(
          city: city,
          isActive: city.cityId == _activeCityId,
          isDeleting: _deletingCityIds.contains(city.cityId),
          onDelete: () => _confirmDelete(city),
          animationIndex: i,
        );
      },
    );
  }
}
