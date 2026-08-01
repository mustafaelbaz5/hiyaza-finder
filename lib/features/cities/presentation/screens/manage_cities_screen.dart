import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/ui/dialogs/app_dialogs.dart';
import '../../domain/entities/cached_city_meta.dart';
import '../../domain/repositories/city_repository.dart';

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
  final CityRepository _repository = getIt<CityRepository>();

  bool _isLoading = true;
  List<CachedCityMeta> _cities = const <CachedCityMeta>[];
  String? _activeCityId;
  final Set<String> _deletingCityIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final List<CachedCityMeta> cities = await _repository.listCachedCities();
    final String? activeCityId = (await _repository.loadActiveCachedSnapshot())?.cityId;
    if (!mounted) return;
    setState(() {
      _cities = cities;
      _activeCityId = activeCityId;
      _isLoading = false;
    });
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
    await _repository.deleteCachedCity(city.cityId);
    if (!mounted) return;
    setState(() {
      _cities = _cities.where((final CachedCityMeta c) => c.cityId != city.cityId).toList();
      _deletingCityIds.remove(city.cityId);
      if (_activeCityId == city.cityId) _activeCityId = null;
    });
    if (mounted) {
      context.showSuccessSnackBar('cities.manage.deleted'.tr());
    }
  }

  String _formatSize(final int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
            Padding(
              padding: EdgeInsets.symmetric(horizontal: rw(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  verticalSpacing(16),
                  Row(
                    children: [
                      const AppBackButton(),
                      horizontalSpacing(12),
                      Expanded(
                        child: Text(
                          'cities.manage.title'.tr(),
                          style: AppTextStyles.font20Bold.copyWith(
                            color: colors.textPrimary,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  verticalSpacing(16),
                ],
              ),
            ),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(final BuildContext context) {
    final colors = context.customColors;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary200),
      );
    }

    if (_cities.isEmpty) {
      return Center(
        child: Text(
          'cities.manage.empty'.tr(),
          style: AppTextStyles.font14Regular.copyWith(color: colors.textHint),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: rw(16)).copyWith(bottom: rh(24)),
      itemCount: _cities.length,
      itemBuilder: (final BuildContext context, final int i) {
        final CachedCityMeta city = _cities[i];
        final bool isActive = city.cityId == _activeCityId;
        final bool isDeleting = _deletingCityIds.contains(city.cityId);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? AppColors.primary200 : colors.border,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary50.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_city_rounded,
                  color: AppColors.primary200,
                ),
              ),
              horizontalSpacing(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isActive) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary200.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'cities.manage.current_badge'.tr(),
                              style: AppTextStyles.font12Bold.copyWith(
                                color: AppColors.primary200,
                              ),
                            ),
                          ),
                          horizontalSpacing(6),
                        ],
                        Expanded(
                          child: Text(
                            city.cityName,
                            style: AppTextStyles.font16SemiBold.copyWith(
                              color: colors.textPrimary,
                            ),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'cities.manage.summary'.tr(
                        namedArgs: {
                          'count': city.parcelsCount.toString(),
                          'size': _formatSize(city.fileSizeBytes),
                        },
                      ),
                      style: AppTextStyles.font12Regular.copyWith(
                        color: colors.textSecondary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
              horizontalSpacing(8),
              if (isDeleting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.red200,
                  ),
                )
              else
                IconButton(
                  tooltip: 'cities.manage.delete'.tr(),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.red200,
                  ),
                  onPressed: () => _confirmDelete(city),
                ),
            ],
          ),
        );
      },
    );
  }
}
