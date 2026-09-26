import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../../core/widgets/custom_text_form_.dart';
import '../../../../core/widgets/ui/dialogs/choice_dialog.dart';
import 'jazla_area_dialog.dart';

class JazlaCreateValue {
  const JazlaCreateValue(
      {required this.name, required this.basinName, required this.area});
  final String name;
  final String basinName;
  final JazlaAreaValue area;
}

Future<JazlaCreateValue?> showJazlaCreateWizard(
  final BuildContext context, {
  required final List<String> basins,
}) =>
    showDialog<JazlaCreateValue>(
      context: context,
      builder: (final _) => _JazlaCreateWizard(basins: basins),
    );

class _JazlaCreateWizard extends StatefulWidget {
  const _JazlaCreateWizard({required this.basins});
  final List<String> basins;

  @override
  State<_JazlaCreateWizard> createState() => _JazlaCreateWizardState();
}

class _JazlaCreateWizardState extends State<_JazlaCreateWizard> {
  final TextEditingController _name = TextEditingController();
  int _step = 0;
  String? _basin;
  JazlaAreaValue _area = const JazlaAreaValue();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickBasin() async {
    final ChoiceDialogResult<String>? result = await showChoiceDialog<String>(
      context,
      title: 'jazla.basin'.tr(),
      options: [
        for (final String basin in widget.basins)
          ChoiceOption(value: basin, label: basin)
      ],
      selected: _basin,
    );
    if (result != null && mounted) {
      setState(() => _basin = result.value);
    }
  }

  Future<void> _pickArea() async {
    final JazlaAreaValue? value =
        await showJazlaAreaDialog(context, initial: _area);
    if (value != null && mounted) setState(() => _area = value);
  }

  void _next() {
    if (_step == 0 && _name.text.trim().isEmpty) return;
    if (_step == 1 && _basin == null) return;
    if (_step < 2) {
      setState(() => _step++);
    } else {
      Navigator.pop(
          context,
          JazlaCreateValue(
              name: _name.text.trim(), basinName: _basin!, area: _area));
    }
  }

  @override
  Widget build(final BuildContext context) => Dialog(
        child: Padding(
          padding: EdgeInsets.all(rw(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('jazla.new_jazla'.tr(),
                  textAlign: TextAlign.center, style: AppTextStyles.font18Bold),
              verticalSpacing(8),
              Text('${_step + 1} / 3', textAlign: TextAlign.center),
              verticalSpacing(16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _step == 0
                    ? CustomTextForm(
                        hintText: 'jazla.name_hint'.tr(),
                        controller: _name,
                        autofocus: true,
                        isRTL: true)
                    : _step == 1
                        ? OutlinedButton.icon(
                            onPressed: _pickBasin,
                            icon: const Icon(Icons.location_on_outlined),
                            label: Text(_basin ?? 'jazla.basin'.tr()))
                        : OutlinedButton.icon(
                            onPressed: _pickArea,
                            icon: const Icon(Icons.straighten_rounded),
                            label: Text(_area.squareMeters == null &&
                                    _area.feddan == null
                                ? 'jazla.area.no_target'.tr()
                                : 'jazla.area.target'.tr())),
              ),
              verticalSpacing(18),
              Row(
                children: [
                  if (_step > 0)
                    Expanded(
                        child: CustomTextButton.outlined(
                            text: 'app_dialogs.back'.tr(),
                            size: CustomButtonSize.small,
                            onPressed: () => setState(() => _step--))),
                  if (_step > 0) horizontalSpacing(8),
                  Expanded(
                      child: CustomTextButton(
                          text: _step == 2
                              ? 'app_dialogs.save'.tr()
                              : 'app_dialogs.next'.tr(),
                          size: CustomButtonSize.small,
                          onPressed: _next)),
                ],
              ),
            ],
          ),
        ),
      );
}
