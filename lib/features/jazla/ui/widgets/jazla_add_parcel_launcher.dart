import 'package:flutter/material.dart';

import '../jazla_add_parcel_screen.dart';

/// Thin re-export so [JazlaDetailScreen] doesn't need to know the screen
/// file's exact path — kept as its own file to match this codebase's
/// one-name-per-file convention without duplicating the navigation code.
///
/// A full-screen modal (not a bottom sheet) — a modal sheet's keyboard used
/// to cover the search bar. Always awaited by the caller (`JazlaDetailScreen`),
/// which reloads its own `JazlaDetailCubit` once this resolves — regardless
/// of *how* the screen closed. Each Jazla cubit (list/detail/add-parcel)
/// owns only its own screen's state, so a write made through the add-parcel
/// screen's cubit never reaches the detail screen's already-built cubit on
/// its own; the caller has to explicitly refresh on return — the same
/// pattern already used for the home search results after returning from
/// Detail Screen.
Future<void> showJazlaAddParcelSheet(
  final BuildContext context, {
  required final String jazlaId,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (final BuildContext context) => JazlaAddParcelScreen(jazlaId: jazlaId),
    ),
  );
}
