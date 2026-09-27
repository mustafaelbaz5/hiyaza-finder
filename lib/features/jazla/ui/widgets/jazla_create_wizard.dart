import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../../core/widgets/custom_text_form_.dart';
import '../../../../core/widgets/ui/buttons/app_icon_button.dart';
import '../../../../core/widgets/ui/dialogs/choice_dialog.dart';
import 'jazla_area_dialog.dart';

/// The value returned by the single-sheet Jazla creation flow.
class JazlaCreateValue {
  const JazlaCreateValue({
    required this.name,
    required this.basinName,
    required this.area,
  });

  final String name;
  final String basinName;
  final JazlaAreaValue area;
}

/// Opens one keyboard-safe sheet rather than the previous sequence of dialogs.
Future<JazlaCreateValue?> showJazlaCreateWizard(
  final BuildContext context, {
  required final List<String> basins,
}) {
  return showModalBottomSheet<JazlaCreateValue>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (final BuildContext context) => _JazlaCreateSheet(basins: basins),
  );
}

class _JazlaCreateSheet extends StatefulWidget {
  const _JazlaCreateSheet({required this.basins});

  final List<String> basins;

  @override
  State<_JazlaCreateSheet> createState() => _JazlaCreateSheetState();
}

class _JazlaCreateSheetState extends State<_JazlaCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _squareMetersController = TextEditingController();
  final _feddanController = TextEditingController();
  final _qiratController = TextEditingController();
  final _sahmController = TextEditingController();

  String? _basin;
  bool _useSquareMeters = true;
  bool _submitted = false;
  String? _areaError;

  @override
  void dispose() {
    _nameController.dispose();
    _squareMetersController.dispose();
    _feddanController.dispose();
    _qiratController.dispose();
    _sahmController.dispose();
    super.dispose();
  }

  double? _parse(final String value) {
    final String normalized = value.trim().replaceAll('٫', '.');
    return normalized.isEmpty ? null : double.tryParse(normalized);
  }

  JazlaAreaValue? _buildArea() {
    if (_useSquareMeters) {
      if (_squareMetersController.text.trim().isEmpty) {
        return const JazlaAreaValue();
      }
      final double? squareMeters = _parse(_squareMetersController.text);
      if (squareMeters == null || squareMeters < 0) return null;
      return JazlaAreaValue(squareMeters: squareMeters);
    }

    final double? feddan = _parse(_feddanController.text);
    final double? qirat = _parse(_qiratController.text);
    final double? sahm = _parse(_sahmController.text);
    final List<double> values =
        <double?>[feddan, qirat, sahm].whereType<double>().toList();
    if (values.isEmpty) return const JazlaAreaValue();
    if (values.any((final double value) => value < 0)) {
      return null;
    }
    return JazlaAreaValue(feddan: feddan, qirat: qirat, sahm: sahm);
  }

  void _submit() {
    setState(() => _submitted = true);
    final bool formIsValid = _formKey.currentState?.validate() ?? false;
    final JazlaAreaValue? area = _buildArea();
    setState(
        () => _areaError = area == null ? 'jazla.area.invalid'.tr() : null);
    if (!formIsValid || area == null || _basin == null) return;

    Navigator.pop(
      context,
      JazlaCreateValue(
        name: _nameController.text.trim(),
        basinName: _basin!,
        area: area,
      ),
    );
  }

  Future<void> _pickBasin() async {
    final ChoiceDialogResult<String>? result = await showChoiceDialog<String>(
      context,
      title: 'holdings.fields.basin_name'.tr(),
      options: widget.basins
          .map(
            (final String basin) => ChoiceOption<String>(
              value: basin,
              label: basin,
              icon: Icons.water_drop_outlined,
            ),
          )
          .toList(),
      selected: _basin,
    );
    if (!mounted || result == null || result.isClear || result.value == null) {
      return;
    }
    setState(() => _basin = result.value);
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final EdgeInsets keyboardInsets = MediaQuery.viewInsetsOf(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.86,
        child: Material(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            children: [
              _SheetHeader(onClose: () => Navigator.pop(context)),
              Divider(height: 1, color: colors.border),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding:
                        EdgeInsets.fromLTRB(rw(20), rh(18), rw(20), rh(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionTitle(
                          icon: Icons.edit_note_rounded,
                          title: 'jazla.create.name_section'.tr(),
                        ),
                        verticalSpacing(8),
                        CustomTextForm(
                          hintText: 'jazla.name_hint'.tr(),
                          controller: _nameController,
                          autofocus: true,
                          isRTL: true,
                          textInputAction: TextInputAction.next,
                          validator: (final String? value) =>
                              value?.trim().isEmpty ?? true
                                  ? 'jazla.create.name_required'.tr()
                                  : null,
                        ),
                        verticalSpacing(22),
                        _SectionTitle(
                          icon: Icons.location_on_outlined,
                          title: 'jazla.create.location_section'.tr(),
                        ),
                        verticalSpacing(8),
                        _BasinSelector(
                          selectedBasin: _basin,
                          errorText: _submitted && _basin == null
                              ? 'jazla.create.basin_required'.tr()
                              : null,
                          onTap: _pickBasin,
                        ),
                        verticalSpacing(22),
                        _SectionTitle(
                          icon: Icons.straighten_rounded,
                          title: 'jazla.area.target'.tr(),
                        ),
                        verticalSpacing(4),
                        Text(
                          'jazla.area.dialog_hint'.tr(),
                          style: AppTextStyles.font12Regular
                              .copyWith(color: colors.textSecondary),
                          textAlign: TextAlign.right,
                        ),
                        verticalSpacing(8),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          child: Column(
                            children: [
                              SegmentedButton<bool>(
                                segments: [
                                  ButtonSegment<bool>(
                                    value: true,
                                    icon: const Icon(Icons.square_foot_rounded),
                                    label:
                                        Text('jazla.area.square_meters'.tr()),
                                  ),
                                  ButtonSegment<bool>(
                                    value: false,
                                    icon: const Icon(Icons.agriculture_rounded),
                                    label: Text('jazla.area.feddan_group'.tr()),
                                  ),
                                ],
                                selected: <bool>{_useSquareMeters},
                                onSelectionChanged: (final Set<bool> value) =>
                                    setState(() {
                                  _useSquareMeters = value.first;
                                  _areaError = null;
                                }),
                              ),
                              verticalSpacing(12),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _useSquareMeters
                                    ? CustomTextForm(
                                        key: const ValueKey<String>('sqm'),
                                        hintText:
                                            'jazla.area.square_meters'.tr(),
                                        controller: _squareMetersController,
                                        isRTL: true,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        inputFormatters: <TextInputFormatter>[
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9٫.]'),
                                          ),
                                        ],
                                      )
                                    : _AgriculturalAreaFields(
                                        feddanController: _feddanController,
                                        qiratController: _qiratController,
                                        sahmController: _sahmController,
                                      ),
                              ),
                            ],
                          ),
                        ),
                        if (_areaError != null) ...[
                          verticalSpacing(8),
                          Text(
                            _areaError!,
                            style: AppTextStyles.font12Regular
                                .copyWith(color: AppColors.red200),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: colors.border),
              Padding(
                padding: EdgeInsets.fromLTRB(rw(20), rh(12), rw(20), rh(16)),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomTextButton.outlined(
                        text: 'app_dialogs.cancel'.tr(),
                        size: CustomButtonSize.small,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    horizontalSpacing(10),
                    Expanded(
                      flex: 2,
                      child: CustomTextButton(
                        text: 'app_dialogs.save'.tr(),
                        size: CustomButtonSize.small,
                        prefixIcon: const Icon(Icons.check_rounded),
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(rw(20), rh(12), rw(12), rh(10)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'jazla.new_jazla'.tr(),
              style:
                  AppTextStyles.font18Bold.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.right,
            ),
          ),
          AppIconButton(
            tooltip: 'app_dialogs.cancel'.tr(),
            onPressed: onClose,
            icon: Icons.close_rounded,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.primary200),
        horizontalSpacing(8),
        Text(
          title,
          style:
              AppTextStyles.font14SemiBold.copyWith(color: colors.textPrimary),
        ),
      ],
    );
  }
}

class _BasinSelector extends StatelessWidget {
  const _BasinSelector({
    required this.selectedBasin,
    required this.errorText,
    required this.onTap,
  });

  final String? selectedBasin;
  final String? errorText;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Semantics(
      button: true,
      label: 'jazla.create.location_section'.tr(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.surface,
            contentPadding:
                const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: errorText == null ? colors.border : AppColors.red200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: errorText == null ? colors.border : AppColors.red200,
              ),
            ),
            errorText: errorText,
            errorStyle: const TextStyle(height: 0.9),
          ),
          child: Row(
            children: [
              Icon(Icons.water_drop_outlined, color: colors.iconSecondary),
              horizontalSpacing(10),
              Expanded(
                child: Text(
                  selectedBasin ?? 'jazla.create.basin_hint'.tr(),
                  textAlign: TextAlign.right,
                  style: AppTextStyles.font14Regular.copyWith(
                    color: selectedBasin == null
                        ? colors.textHint
                        : colors.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.unfold_more_rounded, color: colors.iconSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgriculturalAreaFields extends StatelessWidget {
  const _AgriculturalAreaFields({
    required this.feddanController,
    required this.qiratController,
    required this.sahmController,
  });

  final TextEditingController feddanController;
  final TextEditingController qiratController;
  final TextEditingController sahmController;

  @override
  Widget build(final BuildContext context) {
    final List<TextEditingController> controllers = <TextEditingController>[
      feddanController,
      qiratController,
      sahmController,
    ];
    final List<String> labels = <String>[
      'jazla.area.feddan'.tr(),
      'jazla.area.qirat'.tr(),
      'jazla.area.sahm'.tr(),
    ];
    return Row(
      children: List<Widget>.generate(3, (final int index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: index == 2 ? 0 : 8),
            child: CustomTextForm(
              hintText: labels[index],
              controller: controllers[index],
              isRTL: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9٫.]')),
              ],
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            ),
          ),
        );
      }),
    );
  }
}
