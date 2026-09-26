import 'package:flutter/material.dart';

/// Lays [children] out as a wrap that adapts to the available width: two
/// columns on phones, three on tablets, four on laptop/desktop — keeps a
/// card with many fields short instead of one long scrolling list. Two
/// columns on phones (`REFACTOR_ROADMAP.md` Phase 9 #5) rather than one:
/// most field values here (رقم الحيازة, الرقم القومي, المساحة, …) are short
/// enough that a single-column layout mostly wastes horizontal space and
/// forces more scrolling than the content needs.
class ResponsiveFieldsWrap extends StatelessWidget {
  const ResponsiveFieldsWrap({super.key, required this.children});

  final List<Widget> children;

  static const double _spacing = 8;

  @override
  Widget build(final BuildContext context) {
    return LayoutBuilder(
      builder: (final BuildContext context, final BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int columns =
            width >= 900 ? 4 : (width >= 520 ? 3 : (width >= 300 ? 2 : 1));
        final double itemWidth =
            columns == 1 ? width : (width - _spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final Widget child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}
