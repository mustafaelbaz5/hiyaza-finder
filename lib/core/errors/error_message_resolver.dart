import 'package:easy_localization/easy_localization.dart';

import 'exceptions.dart';

/// Maps a caught write-action error to a translated, accurate message —
/// the single place every `catch` block in the holdings feature should go
/// through instead of hand-picking a generic `*_failed` string
/// (`REFACTOR_ROADMAP.md` Phase 21). [ErrorHandler.handleException]
/// (`error_handler.dart`) already classifies raw exceptions into
/// [AppException] subtypes, including real connectivity failures
/// ([NetworkException]/[TimeoutException]) that previously fell through to
/// a generic server error — this only needs to turn that classification
/// into user-facing text, not re-derive it.
///
/// [fallback] is action-specific text used only for the "genuinely
/// server-rejected, no more specific type available" case — every other
/// branch below already has its own accurate, shared message.
///
/// [timeoutOutcomeUncertain] (`REFACTOR_ROADMAP.md` Phase 25) opts a
/// [TimeoutException] into `errors.timeout_uncertain` instead of the plain
/// `errors.timeout` string — only for write actions where a `.timeout()`
/// firing does NOT mean the request definitely failed, because the RPC/write
/// may have already committed server-side by the time the client gave up
/// waiting (e.g. `HoldingsRepository.setParcelCompleted`'s
/// `mark_parcel_completed` RPC). Most write actions (an edit, a delete) are
/// NOT idempotent-safe to reconcile this way and should keep the plain,
/// unambiguous "try again" wording — this only applies where the caller is
/// also following up with an actual reconciliation read (see
/// `HoldingsRepository.refreshParcel`), not just wherever a timeout might
/// theoretically be retried.
String resolveWriteErrorMessage(
  final Object error, {
  required final String fallback,
  final bool timeoutOutcomeUncertain = false,
}) {
  if (error is NetworkException) return 'errors.no_internet'.tr();
  if (error is TimeoutException) {
    return (timeoutOutcomeUncertain ? 'errors.timeout_uncertain' : 'errors.timeout').tr();
  }
  if (error is ConflictException) return 'errors.conflict'.tr();
  if (error is ValidationException) return 'errors.validation'.tr();
  if (error is ForbiddenException) return 'errors.forbidden'.tr();
  if (error is UnauthorizedException) return 'errors.unauthorized'.tr();
  if (error is NotFoundException) return 'errors.not_found'.tr();
  return fallback;
}
