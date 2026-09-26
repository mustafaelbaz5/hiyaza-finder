import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../../core/widgets/custom_text_form_.dart';

class JazlaAreaValue {
  const JazlaAreaValue({this.squareMeters, this.feddan, this.qirat, this.sahm});

  final double? squareMeters;
  final double? feddan;
  final double? qirat;
  final double? sahm;
}

Future<JazlaAreaValue?> showJazlaAreaDialog(
  final BuildContext context, {
  final JazlaAreaValue initial = const JazlaAreaValue(),
}) {
  return showDialog<JazlaAreaValue>(
    context: context,
    builder: (final BuildContext dialogContext) =>
        _JazlaAreaDialog(initial: initial),
  );
}

class _JazlaAreaDialog extends StatefulWidget {
  const _JazlaAreaDialog({required this.initial});

  final JazlaAreaValue initial;

  @override
  State<_JazlaAreaDialog> createState() => _JazlaAreaDialogState();
}

class _JazlaAreaDialogState extends State<_JazlaAreaDialog> {
  late bool _useSquareMeters = widget.initial.squareMeters != null ||
      (widget.initial.feddan == null &&
          widget.initial.qirat == null &&
          widget.initial.sahm == null);
  late final TextEditingController _feddan = TextEditingController(
    text: _format(widget.initial.feddan),
  );
  late final TextEditingController _qirat = TextEditingController(
    text: _format(widget.initial.qirat),
  );
  late final TextEditingController _sahm = TextEditingController(
    text: _format(widget.initial.sahm),
  );
  String? _error;

  static String _format(final double? value) => value == null
      ? ''
      : value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString();

  static double? _parse(final String raw) {
    final String value = raw.trim().replaceAll('٫', '.');
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  void _save() {
    if (_useSquareMeters) {
      final double? squareMeters = _parse(_squareMeters.text);
      if (squareMeters == null || squareMeters < 0) {
        setState(() => _error = 'jazla.area.invalid'.tr());
        return;
      }
      Navigator.pop(context, JazlaAreaValue(squareMeters: squareMeters));
      return;
    }
    final double? feddan = _parse(_feddan.text);
    final double? qirat = _parse(_qirat.text);
    final double? sahm = _parse(_sahm.text);
    final List<double> values =
        [feddan, qirat, sahm].whereType<double>().toList();
    if (values.any((final double value) => value < 0)) {
      setState(() => _error = 'jazla.area.invalid'.tr());
      return;
    }
    Navigator.pop(
      context,
      JazlaAreaValue(feddan: feddan, qirat: qirat, sahm: sahm),
    );
  }

  late final TextEditingController _squareMeters = TextEditingController(
    text: _format(widget.initial.squareMeters),
  );

  @override
  void dispose() {
    _feddan.dispose();
    _qirat.dispose();
    _sahm.dispose();
    _squareMeters.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: rw(28)),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(rr(16))),
      backgroundColor: colors.surface,
      child: Padding(
        padding: EdgeInsets.all(rw(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'jazla.area.dialog_title'.tr(),
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.font18Bold.copyWith(color: colors.textPrimary),
            ),
            verticalSpacing(8),
            Text(
              'jazla.area.dialog_hint'.tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.font12Regular
                  .copyWith(color: colors.textSecondary),
            ),
            verticalSpacing(16),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                    value: true, label: Text('jazla.area.square_meters'.tr())),
                ButtonSegment(
                    value: false, label: Text('jazla.area.feddan_group'.tr())),
              ],
              selected: <bool>{_useSquareMeters},
              onSelectionChanged: (final Set<bool> value) => setState(() {
                _useSquareMeters = value.first;
                _error = null;
              }),
            ),
            verticalSpacing(12),
            if (_useSquareMeters)
              CustomTextForm(
                hintText: 'jazla.area.square_meters'.tr(),
                controller: _squareMeters,
                isRTL: true,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            if (!_useSquareMeters) ...[
              CustomTextForm(
                hintText: 'jazla.area.feddan'.tr(),
                controller: _feddan,
                isRTL: true,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              verticalSpacing(10),
              CustomTextForm(
                hintText: 'jazla.area.qirat'.tr(),
                controller: _qirat,
                isRTL: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              verticalSpacing(10),
              CustomTextForm(
                hintText: 'jazla.area.sahm'.tr(),
                controller: _sahm,
                isRTL: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            if (_error != null) ...[
              verticalSpacing(8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.red200)),
            ],
            verticalSpacing(18),
            Row(
              children: [
                Expanded(
                  child: CustomTextButton.outlined(
                    text: 'app_dialogs.cancel'.tr(),
                    size: CustomButtonSize.small,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                horizontalSpacing(8),
                Expanded(
                  child: CustomTextButton(
                    text: 'app_dialogs.save'.tr(),
                    size: CustomButtonSize.small,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
