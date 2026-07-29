import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../data/models/cached_file_entry.dart';
import '../../data/repository/holdings_repository.dart';

/// Lists every workbook the user has ever loaded so they can switch back
/// to one without re-picking it from disk.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HoldingsRepository _repository = getIt<HoldingsRepository>();
  late Future<List<CachedFileEntry>> _historyFuture;
  bool _isOpeningEntry = false;

  @override
  void initState() {
    super.initState();
    _historyFuture = _repository.getHistory();
  }

  void _refresh() {
    setState(() => _historyFuture = _repository.getHistory());
  }

  Future<void> _openEntry(final CachedFileEntry entry) async {
    if (_isOpeningEntry) return;
    setState(() => _isOpeningEntry = true);
    try {
      await _repository.loadFromHistoryEntry(entry);
      if (!mounted) return;
      context.pushNamedAndRemoveAll(Routes.home);
    } on HoldingsFilePickCancelled {
      await _repository.removeHistoryEntry(entry);
      if (!mounted) return;
      context.showErrorSnackBar('holdings.history.file_missing'.tr());
      _refresh();
    } catch (e) {
      if (!mounted) return;
      context.showErrorSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isOpeningEntry = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            verticalSpacing(16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: rw(16)),
              child: Row(
                children: [
                  const AppBackButton(),
                  horizontalSpacing(12),
                  Expanded(
                    child: Text(
                      'holdings.history.title'.tr(),
                      style: AppTextStyles.font20Bold.copyWith(
                        color: colors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            verticalSpacing(16),
            Expanded(
              child: FutureBuilder<List<CachedFileEntry>>(
                future: _historyFuture,
                builder: (final BuildContext context, final snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary200,
                      ),
                    );
                  }

                  final List<CachedFileEntry> entries =
                      snapshot.data ?? const <CachedFileEntry>[];
                  if (entries.isEmpty) {
                    return Center(
                      child: Text(
                        'holdings.history.empty'.tr(),
                        style: AppTextStyles.font16Regular.copyWith(
                          color: colors.textHint,
                        ),
                      ),
                    ).animate().fadeIn(duration: 250.ms);
                  }

                  return AbsorbPointer(
                    absorbing: _isOpeningEntry,
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: rw(16),
                      ).copyWith(bottom: rh(24)),
                      itemCount: entries.length,
                      itemBuilder: (final BuildContext context, final int i) {
                        final CachedFileEntry entry = entries[i];
                        return _HistoryTile(
                          entry: entry,
                          onTap: () => _openEntry(entry),
                        )
                            .animate()
                            .fadeIn(
                              duration: 220.ms,
                              delay: (i * 30).ms,
                            )
                            .slideY(
                              begin: 0.08,
                              end: 0,
                              duration: 220.ms,
                              delay: (i * 30).ms,
                              curve: Curves.easeOutCubic,
                            );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.onTap});

  final CachedFileEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String formattedDate = DateFormat(
      'yyyy/MM/dd – HH:mm',
    ).format(entry.cachedAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary50.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.description_rounded,
                color: AppColors.primary200,
              ),
            ),
            horizontalSpacing(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.fileName,
                    style: AppTextStyles.font16SemiBold.copyWith(
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'holdings.history.holdings_count'.tr(
                      namedArgs: {'count': entry.holdingCount.toString()},
                    ),
                    style: AppTextStyles.font12Regular.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedDate,
                    style: AppTextStyles.font12Regular.copyWith(
                      color: colors.textHint,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: AppColors.primary200,
            ),
          ],
        ),
      ),
    );
  }
}
