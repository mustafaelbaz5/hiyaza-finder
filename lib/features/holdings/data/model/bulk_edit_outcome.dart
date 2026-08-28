/// Result of `HoldingsRepository.bulkApplyField` — how many of the rows in
/// scope were confirmed by the server vs. failed, so a partial failure can
/// be reported to the user instead of silently discarding progress made on
/// the rest of the batch.
class BulkEditOutcome {
  const BulkEditOutcome({required this.succeeded, required this.failed});

  final int succeeded;
  final int failed;

  int get total => succeeded + failed;
}
