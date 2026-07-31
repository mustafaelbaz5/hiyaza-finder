import 'package:flutter/material.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/crop_type_picker.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/picker_row.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/section_card.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../../core/widgets/ui/dialogs/choice_dialog.dart';
import '../../domain/entities/bulk_editable_field.dart';
import '../../data/repository/holdings_repository.dart';

/// Overview of the active city's data — holding counts per حوض — plus a
/// bulk edit tool applying one of the app-added fields (نوع الزرع،
/// ملاحظات، …) to every parcel in one حوض (or the whole city) at once.
class FileStatusScreen extends StatefulWidget {
  const FileStatusScreen({super.key});

  @override
  State<FileStatusScreen> createState() => _FileStatusScreenState();
}

class _FileStatusScreenState extends State<FileStatusScreen> {
  final HoldingsRepository _repository = getIt<HoldingsRepository>();

  String? _bulkBasin; // null = whole file
  BulkEditableField _bulkField = BulkEditableField.cropType;
  Object? _bulkValue;

  Future<void> _pickBulkBasin() async {
    final List<String> basins = _repository.availableBasins;
    final ChoiceDialogResult<String>? result = await showChoiceDialog<String>(
      context,
      title: 'اختر الحوض',
      options: [
        for (final String b in basins) ChoiceOption<String>(value: b, label: b),
      ],
      selected: _bulkBasin,
      clearLabel: 'كل الأحواض',
    );
    if (result == null) return;
    setState(() {
      _bulkBasin = result.isClear ? null : result.value;
    });
  }

  Future<void> _pickBulkField() async {
    final ChoiceDialogResult<BulkEditableField>? result =
        await showChoiceDialog<BulkEditableField>(
      context,
      title: 'اختر الحقل',
      options: [
        for (final BulkEditableField f in BulkEditableField.values)
          ChoiceOption<BulkEditableField>(value: f, label: f.label),
      ],
      selected: _bulkField,
    );
    if (result == null || result.isClear) return;
    setState(() {
      _bulkField = result.value!;
      _bulkValue = null;
    });
  }

  Future<void> _pickBulkValue() async {
    if (_bulkField.isBoolean) {
      final ChoiceDialogResult<bool>? result = await showChoiceDialog<bool>(
        context,
        title: _bulkField.label,
        options: const [
          ChoiceOption<bool>(value: true, label: 'وراثة'),
          ChoiceOption<bool>(value: false, label: 'ليست وراثة'),
        ],
        selected: _bulkValue as bool?,
      );
      if (result == null || result.isClear) return;
      setState(() => _bulkValue = result.value);
      return;
    }

    if (_bulkField == BulkEditableField.cropType) {
      final ChoiceDialogResult<String>? result = await pickCropType(
        context,
        selected: _bulkValue as String?,
      );
      if (result == null) return;
      setState(() => _bulkValue = result.isClear ? null : result.value);
      return;
    }

    final ChoiceDialogResult<String>? result = await showChoiceDialog<String>(
      context,
      title: _bulkField.label,
      options: [
        for (final String o in _bulkField.textOptions)
          ChoiceOption<String>(value: o, label: o),
      ],
      selected: _bulkValue as String?,
      clearLabel: _bulkField.allowClear ? '—' : null,
    );
    if (result == null) return;
    setState(() => _bulkValue = result.isClear ? null : result.value);
  }

  Future<void> _applyBulkEdit() async {
    final int changed = await _repository.bulkApplyField(
      field: _bulkField,
      value: _bulkValue,
      basin: _bulkBasin,
    );
    if (!mounted) return;
    setState(() {});
    context.showSuccessSnackBar('تم تحديث $changed سجل');
  }

  String _valueLabel(final Object? value) {
    if (value == null) return '—';
    if (value is bool) return value ? 'وراثة' : 'ليست وراثة';
    return value as String;
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final Map<String, int> counts = _repository.basinHoldingCounts;
    final List<String> basins = _repository.availableBasins;

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
                          'حالة الملف',
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
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: rw(16)).copyWith(
                  bottom: rh(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionCard(
                      title: 'الأحواض',
                      subtitle: 'عدد الحيازات في كل حوض',
                      child: basins.isEmpty
                          ? Text(
                              'لا توجد أحواض في هذا الملف',
                              style: AppTextStyles.font14Regular.copyWith(
                                color: colors.textHint,
                              ),
                              textAlign: TextAlign.right,
                            )
                          : Column(
                              children: [
                                for (final String basin in basins)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary50
                                                .withValues(alpha: 0.3),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${counts[basin] ?? 0}',
                                            style: AppTextStyles.font12Bold
                                                .copyWith(
                                              color: AppColors.primary200,
                                            ),
                                          ),
                                        ),
                                        horizontalSpacing(8),
                                        Expanded(
                                          child: Text(
                                            basin,
                                            style: AppTextStyles.font14SemiBold
                                                .copyWith(
                                              color: colors.textPrimary,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    verticalSpacing(16),
                    SectionCard(
                      title: 'تعديل جماعي لحقل',
                      subtitle:
                          'يطبَّق على كل حيازات الحوض المختار (أو كل الملف)',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PickerRow(
                            label: 'النطاق',
                            value: _bulkBasin ?? 'كل الأحواض',
                            onTap: _pickBulkBasin,
                          ),
                          verticalSpacing(8),
                          PickerRow(
                            label: 'الحقل',
                            value: _bulkField.label,
                            onTap: _pickBulkField,
                          ),
                          verticalSpacing(8),
                          PickerRow(
                            label: 'القيمة',
                            value: _valueLabel(_bulkValue),
                            onTap: _pickBulkValue,
                          ),
                          verticalSpacing(16),
                          CustomTextButton(
                            text: 'تطبيق',
                            onPressed: _applyBulkEdit,
                            prefixIcon: const Icon(
                              Icons.done_all_rounded,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
