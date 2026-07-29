import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../../core/widgets/custom_text_form_.dart';
import '../../data/models/parcel.dart';
import '../../logic/services/area_calculator.dart';

/// Form for correcting a single parcel's data. The total area (م²) is
/// recomputed live from فدان/قيراط/سهم. Returns the edited [Parcel] via
/// `Navigator.pop`, or nothing if cancelled.
class ParcelEditScreen extends StatefulWidget {
  const ParcelEditScreen({super.key, required this.parcel});

  final Parcel parcel;

  @override
  State<ParcelEditScreen> createState() => _ParcelEditScreenState();
}

class _ParcelEditScreenState extends State<ParcelEditScreen> {
  late final TextEditingController _ownerName;
  late final TextEditingController _holderName;
  late final TextEditingController _nationalId;
  late final TextEditingController _basinName;
  late final TextEditingController _basinCode;
  late final TextEditingController _directorate;
  late final TextEditingController _administration;
  late final TextEditingController _landNumber;
  late final TextEditingController _feddan;
  late final TextEditingController _qirat;
  late final TextEditingController _sahm;

  double? _computedTotal;
  String? _cropType;
  String? _notes;
  late String _creditType;
  late String _usageType;
  late bool _isInheritance;

  @override
  void initState() {
    super.initState();
    final Parcel p = widget.parcel;
    _ownerName = TextEditingController(text: p.ownerName ?? '');
    _holderName = TextEditingController(text: p.holderName ?? '');
    _nationalId = TextEditingController(text: p.nationalId ?? '');
    _basinName = TextEditingController(text: p.basinName ?? '');
    _basinCode = TextEditingController(text: p.basinCode ?? '');
    _directorate = TextEditingController(text: p.directorate ?? '');
    _administration = TextEditingController(text: p.administration ?? '');
    _landNumber = TextEditingController(text: p.landNumber ?? '');
    _feddan = TextEditingController(text: _numToText(p.feddan));
    _qirat = TextEditingController(text: _numToText(p.qirat));
    _sahm = TextEditingController(text: _numToText(p.sahm));
    _computedTotal = p.totalSqm;
    _cropType = p.cropType;
    _notes = p.notes;
    _creditType = p.creditType;
    _usageType = p.usageType;
    _isInheritance = p.isInheritance;
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _ownerName,
      _holderName,
      _nationalId,
      _basinName,
      _basinCode,
      _directorate,
      _administration,
      _landNumber,
      _feddan,
      _qirat,
      _sahm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _recomputeArea() {
    setState(() {
      _computedTotal = AreaCalculator.totalSqm(
        feddan: _parseNum(_feddan.text),
        qirat: _parseNum(_qirat.text),
        sahm: _parseNum(_sahm.text),
      );
    });
  }

  void _save() {
    final Parcel original = widget.parcel;
    final Parcel edited = Parcel(
      id: original.id,
      holdingId: original.holdingId,
      pageNumber: original.pageNumber,
      borderEast: original.borderEast,
      borderSouth: original.borderSouth,
      borderWest: original.borderWest,
      borderNorth: original.borderNorth,
      associationName: original.associationName,
      ownerName: _text(_ownerName),
      holderName: _text(_holderName),
      nationalId: _text(_nationalId),
      basinName: _text(_basinName),
      basinCode: _text(_basinCode),
      directorate: _text(_directorate),
      administration: _text(_administration),
      landNumber: _text(_landNumber),
      feddan: _parseNum(_feddan.text),
      qirat: _parseNum(_qirat.text),
      sahm: _parseNum(_sahm.text),
      totalSqm: AreaCalculator.totalSqm(
        feddan: _parseNum(_feddan.text),
        qirat: _parseNum(_qirat.text),
        sahm: _parseNum(_sahm.text),
      ),
      cropType: _cropType,
      notes: _notes,
      creditType: _creditType,
      isInheritance: _isInheritance,
      usageType: _usageType,
    );
    Navigator.pop(context, edited);
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: rw(16), vertical: rh(8)),
              child: Row(
                children: <Widget>[
                  const AppBackButton(),
                  horizontalSpacing(12),
                  Expanded(
                    child: Text(
                      'holdings.edit.title'.tr(
                        namedArgs: {'id': widget.parcel.holdingId},
                      ),
                      style: AppTextStyles.font20Bold.copyWith(
                        color: colors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: rw(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    verticalSpacing(8),
                    _SectionLabel('holdings.edit.section_holder'.tr()),
                    _LabeledField(label: 'اسم المالك', controller: _ownerName),
                    _LabeledField(
                      label: 'اسم الحائز',
                      controller: _holderName,
                    ),
                    _LabeledField(
                      label: 'الرقم القومي',
                      controller: _nationalId,
                      keyboardType: TextInputType.number,
                    ),
                    _LabeledSwitch(
                      label: 'وراثة',
                      value: _isInheritance,
                      onChanged: (final bool v) =>
                          setState(() => _isInheritance = v),
                    ),
                    verticalSpacing(8),
                    _SectionLabel('holdings.edit.section_location'.tr()),
                    _LabeledField(label: 'اسم الحوض', controller: _basinName),
                    _LabeledField(label: 'كود الحوض', controller: _basinCode),
                    _LabeledField(label: 'المديرية', controller: _directorate),
                    _LabeledField(
                      label: 'الإدارة',
                      controller: _administration,
                    ),
                    _LabeledField(label: 'رقم الأرض', controller: _landNumber),
                    verticalSpacing(8),
                    _SectionLabel('holdings.edit.section_area'.tr()),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _LabeledField(
                            label: 'فدان',
                            controller: _feddan,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (final _) => _recomputeArea(),
                          ),
                        ),
                        horizontalSpacing(10),
                        Expanded(
                          child: _LabeledField(
                            label: 'قيراط',
                            controller: _qirat,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (final _) => _recomputeArea(),
                          ),
                        ),
                        horizontalSpacing(10),
                        Expanded(
                          child: _LabeledField(
                            label: 'سهم',
                            controller: _sahm,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (final _) => _recomputeArea(),
                          ),
                        ),
                      ],
                    ),
                    verticalSpacing(4),
                    _TotalAreaPreview(total: _computedTotal),
                    verticalSpacing(8),
                    _SectionLabel('holdings.edit.section_extra'.tr()),
                    _LabeledDropdown(
                      label: 'نوع الزرع',
                      value: _cropType,
                      options: Parcel.cropTypeOptions,
                      onChanged: (final String? v) =>
                          setState(() => _cropType = v),
                    ),
                    _LabeledDropdown(
                      label: 'ملاحظات',
                      value: _notes,
                      options: Parcel.notesOptions,
                      onChanged: (final String? v) =>
                          setState(() => _notes = v),
                    ),
                    _LabeledDropdown(
                      label: 'نوع الائتمان',
                      value: _creditType,
                      options: Parcel.creditTypeOptions,
                      allowClear: false,
                      onChanged: (final String? v) => setState(
                        () => _creditType = v ?? Parcel.defaultCreditType,
                      ),
                    ),
                    _LabeledDropdown(
                      label: 'نوع الاستخدام',
                      value: _usageType,
                      options: Parcel.usageTypeOptions,
                      allowClear: false,
                      onChanged: (final String? v) => setState(
                        () => _usageType = v ?? Parcel.defaultUsageType,
                      ),
                    ),
                    verticalSpacing(24),
                    CustomTextButton(
                      text: 'holdings.edit.save'.tr(),
                      prefixIcon: const Icon(
                        Icons.check_rounded,
                        color: AppColors.white,
                      ),
                      onPressed: _save,
                    ),
                    verticalSpacing(24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _text(final TextEditingController c) {
    final String t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  static String _numToText(final double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  static double? _parseNum(final String raw) {
    final String s = _toLatinDigits(raw).trim().replaceAll('٫', '.');
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  static String _toLatinDigits(final String input) {
    const String arabic = '٠١٢٣٤٥٦٧٨٩';
    const String persian = '۰۱۲۳۴۵۶۷۸۹';
    final StringBuffer out = StringBuffer();
    for (final String ch in input.split('')) {
      final int ai = arabic.indexOf(ch);
      final int pi = persian.indexOf(ch);
      if (ai >= 0) {
        out.write(ai);
      } else if (pi >= 0) {
        out.write(pi);
      } else {
        out.write(ch);
      }
    }
    return out.toString();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(final BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        label,
        style: AppTextStyles.font12Bold.copyWith(
          color: context.customColors.textSecondary,
          letterSpacing: 1.1,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(final BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: AppTextStyles.font14Regular.copyWith(
              color: context.customColors.textSecondary,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 6),
          CustomTextForm(
            hintText: label,
            controller: controller,
            isRTL: true,
            keyboardType: keyboardType,
            onChanged: onChanged,
            inputFormatters: keyboardType == null
                ? null
                : <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9٠-٩۰-۹.٫]'),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _LabeledDropdown extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.allowClear = true,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool allowClear;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: AppTextStyles.font14Regular.copyWith(
              color: colors.textSecondary,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                initialValue: value,
                isExpanded: true,
                alignment: AlignmentDirectional.centerEnd,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                ),
                items: <DropdownMenuItem<String>>[
                  if (allowClear)
                    const DropdownMenuItem<String>(
                      child: Text('—', textAlign: TextAlign.right),
                    ),
                  for (final String option in options)
                    DropdownMenuItem<String>(
                      value: option,
                      child: Text(option, textAlign: TextAlign.right),
                    ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledSwitch extends StatelessWidget {
  const _LabeledSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: <Widget>[
              Switch(value: value, onChanged: onChanged),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.font14Regular.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalAreaPreview extends StatelessWidget {
  const _TotalAreaPreview({required this.total});

  final double? total;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String value = total == null
        ? '—'
        : (total == total!.roundToDouble()
              ? total!.toInt().toString()
              : total!.toStringAsFixed(2));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary50.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary200),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.calculate_rounded, color: AppColors.primary200),
          horizontalSpacing(10),
          Expanded(
            child: Text(
              'holdings.edit.total_preview'.tr(namedArgs: {'value': value}),
              style: AppTextStyles.font16SemiBold.copyWith(
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
