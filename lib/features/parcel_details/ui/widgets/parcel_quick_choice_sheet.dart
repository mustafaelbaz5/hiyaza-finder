import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';

/// Opens a compact, RTL-safe selector for values users change frequently.
/// The selected item is highlighted in the list; the header stays focused on
/// the action and does not repeat the current value.
Future<String?> showParcelQuickChoiceSheet(
  final BuildContext context, {
  required final String title,
  required final String? selected,
  required final List<String> options,
  final Future<String?> Function()? onAddOption,
}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (final BuildContext sheetContext) => _ParcelQuickChoiceSheet(
        title: title,
        selected: selected,
        options: options,
        onAddOption: onAddOption,
      ),
    );

class _ParcelQuickChoiceSheet extends StatefulWidget {
  const _ParcelQuickChoiceSheet({
    required this.title,
    required this.selected,
    required this.options,
    this.onAddOption,
  });

  final String title;
  final String? selected;
  final List<String> options;
  final Future<String?> Function()? onAddOption;

  @override
  State<_ParcelQuickChoiceSheet> createState() =>
      _ParcelQuickChoiceSheetState();
}

class _ParcelQuickChoiceSheetState extends State<_ParcelQuickChoiceSheet> {
  final String _query = '';

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final MediaQueryData media = MediaQuery.of(context);
    final double maxHeight = media.size.height * 0.68;
    final String query = _query.trim().toLowerCase();
    final List<String> visibleOptions = query.isEmpty
        ? widget.options
        : widget.options
            .where(
                (final String option) => option.toLowerCase().contains(query))
            .toList(growable: false);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.font18Bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  if (widget.onAddOption != null)
                    FilledButton.icon(
                      onPressed: () async {
                        final String? value = await widget.onAddOption!();
                        if (context.mounted && value != null) {
                          Navigator.of(context).pop(value);
                        }
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('إضافة'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: visibleOptions.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'لا توجد قيم مطابقة',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.font14Regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: visibleOptions.length,
                        separatorBuilder:
                            (final BuildContext _, final int __) =>
                                const SizedBox(height: 6),
                        itemBuilder:
                            (final BuildContext context, final int index) {
                          final String option = visibleOptions[index];
                          final bool isSelected = option == widget.selected;
                          final Color borderColor =
                              isSelected ? AppColors.green200 : colors.border;
                          return Material(
                            color: isSelected
                                ? AppColors.green200.withValues(alpha: 0.14)
                                : colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.of(context).pop(option),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: borderColor,
                                    width: isSelected ? 1.4 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons
                                              .radio_button_unchecked_rounded,
                                      color: isSelected
                                          ? AppColors.green200
                                          : colors.textHint,
                                      size: 21,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        option,
                                        textAlign: TextAlign.right,
                                        style: AppTextStyles.font14SemiBold
                                            .copyWith(
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
