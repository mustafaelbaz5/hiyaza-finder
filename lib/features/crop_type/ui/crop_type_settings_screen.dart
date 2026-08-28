import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../holdings/data/repo/holdings_repository.dart';

import '../../../core/di/dependency_injection.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/ui/dialogs/app_dialogs.dart';
import '../../../core/widgets/ui/dialogs/text_input_dialog.dart';
import '../data/repo/crop_type_repo.dart';

/// Lets an admin/editor manage the نوع الزرع options offered to field
/// workers for the currently loaded city (`city_crop_types` table). Only
/// edits the option *list* — never touches a value already saved on an
/// existing parcel. Online-required, same as the rest of "أدوات المدينة".
class CropTypeSettingsScreen extends StatefulWidget {
  const CropTypeSettingsScreen({super.key});

  @override
  State<CropTypeSettingsScreen> createState() => _CropTypeSettingsScreenState();
}

class _CropTypeSettingsScreenState extends State<CropTypeSettingsScreen> {
  final CropTypeRepo _repository = getIt<CropTypeRepo>();
  final String? _cityId = getIt<HoldingsRepository>().activeCityId;

  bool _isLoading = true;
  bool _hasError = false;
  List<String> _cropTypes = const <String>[];
  final Set<String> _pendingRemovals = <String>{};
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final String? cityId = _cityId;
    if (cityId == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final List<String> cropTypes = await _repository.fetchCropTypes(cityId);
      if (!mounted) return;
      setState(() {
        _cropTypes = cropTypes;
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

  Future<void> _addCropType() async {
    final String? cityId = _cityId;
    if (cityId == null) return;

    final String? value = await showTextInputDialog(
      context,
      title: 'cities.tools.crop_types.add_title'.tr(),
      initialValue: '',
    );
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return;
    if (_cropTypes.contains(trimmed)) return;

    setState(() => _isAdding = true);
    try {
      await _repository.addCropType(cityId, trimmed);
      if (!mounted) return;
      setState(() {
        _cropTypes = <String>[..._cropTypes, trimmed];
        _isAdding = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAdding = false);
      context.showErrorSnackBar('errors.unknown'.tr());
    }
  }

  Future<void> _confirmRemove(final String cropType) async {
    await AppDialogs.showConfirm(
      context,
      message: 'cities.tools.crop_types.remove_confirm'.tr(
        namedArgs: {'name': cropType},
      ),
      onConfirm: () => _remove(cropType),
    );
  }

  Future<void> _remove(final String cropType) async {
    final String? cityId = _cityId;
    if (cityId == null) return;

    setState(() => _pendingRemovals.add(cropType));
    try {
      await _repository.removeCropType(cityId, cropType);
      if (!mounted) return;
      setState(() {
        _cropTypes =
            _cropTypes.where((final String c) => c != cropType).toList();
        _pendingRemovals.remove(cropType);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingRemovals.remove(cropType));
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
            ScreenHeader(title: 'cities.tools.crop_types.title'.tr()),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
      floatingActionButton: _cityId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _isAdding ? null : _addCropType,
              backgroundColor: AppColors.primary200,
              foregroundColor: AppColors.white,
              icon: _isAdding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text('cities.tools.crop_types.add'.tr()),
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

    if (_cityId == null) {
      return Center(
        child: Text(
          'cities.tools.crop_types.no_active_city'.tr(),
          style: AppTextStyles.font14Regular.copyWith(color: colors.textHint),
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'errors.unknown'.tr(),
              style: AppTextStyles.font14Regular
                  .copyWith(color: colors.textSecondary),
            ),
            verticalSpacing(12),
            TextButton(
              onPressed: _load,
              child: Text('app_dialogs.retry'.tr()),
            ),
          ],
        ),
      );
    }

    if (_cropTypes.isEmpty) {
      return Center(
        child: Text(
          'cities.tools.crop_types.empty'.tr(),
          style: AppTextStyles.font14Regular.copyWith(color: colors.textHint),
        ),
      );
    }

    return ListView.builder(
      padding:
          EdgeInsets.symmetric(horizontal: rw(16)).copyWith(bottom: rh(80)),
      itemCount: _cropTypes.length,
      itemBuilder: (final BuildContext context, final int i) {
        final String cropType = _cropTypes[i];
        final bool isRemoving = _pendingRemovals.contains(cropType);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  cropType,
                  style: AppTextStyles.font16SemiBold
                      .copyWith(color: colors.textPrimary),
                  textAlign: TextAlign.right,
                ),
              ),
              isRemoving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.red200,
                      ),
                      onPressed: () => _confirmRemove(cropType),
                    ),
            ],
          ),
        );
      },
    );
  }
}
