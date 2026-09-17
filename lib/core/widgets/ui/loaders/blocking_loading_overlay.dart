import 'package:flutter/material.dart';

/// Full-screen, modal loading veil for a write action that must be
/// server-confirmed before the user can do anything else (`REFACTOR_ROADMAP.md`
/// Phase 23 — "Action → blocking loading → confirmed success/accurate
/// error"). Unlike the per-card inline spinners (`_busyParcelIds` etc.),
/// which only stop a *second tap on the same row*, this additionally blocks
/// navigation (back gesture/button) and every other on-screen control while
/// [visible] is true, so a critical write can never be left in an ambiguous
/// "did it go through?" state by the user leaving the screen mid-request.
///
/// Wrap the screen's body: `BlockingLoadingOverlay(visible: _isSaving, message:
/// ..., child: Scaffold(...))`. Absorbs taps via a transparent
/// [ModalBarrier] and disables the system back gesture via [PopScope] —
/// callers don't need their own `PopScope`/`WillPopScope` for this specific
/// case.
class BlockingLoadingOverlay extends StatelessWidget {
  const BlockingLoadingOverlay({
    super.key,
    required this.visible,
    required this.child,
    this.message,
  });

  final bool visible;
  final Widget child;
  final String? message;

  @override
  Widget build(final BuildContext context) {
    return PopScope(
      canPop: !visible,
      child: Stack(
        children: <Widget>[
          child,
          if (visible)
            Positioned.fill(
              child: Stack(
                children: <Widget>[
                  const ModalBarrier(dismissible: false, color: Colors.black45),
                  Center(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const CircularProgressIndicator(),
                            if (message != null) ...<Widget>[
                              const SizedBox(height: 16),
                              Text(
                                message!,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
