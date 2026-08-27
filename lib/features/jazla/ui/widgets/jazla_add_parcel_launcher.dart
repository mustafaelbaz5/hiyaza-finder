import 'package:flutter/material.dart';

import '../jazla_add_parcel_sheet.dart';

/// Thin re-export so [JazlaDetailScreen] doesn't need to know the sheet
/// file's exact path — kept as its own file to match this codebase's
/// one-name-per-file convention without duplicating the sheet's code.
Future<void> showJazlaAddParcelSheet(
  final BuildContext context, {
  required final String jazlaId,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (final BuildContext context) => JazlaAddParcelSheet(jazlaId: jazlaId),
    );
