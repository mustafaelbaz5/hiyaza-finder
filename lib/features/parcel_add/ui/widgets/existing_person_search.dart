import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hiyaza_finder/features/parcel_add/data/local/existing_person_candidates.dart';
import 'package:hiyaza_finder/features/parcel_search/data/local/holding_search_service.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/repo/parcel_catalog_repository.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_form_.dart';

/// Exact holding-number search for adding a parcel to an existing person.
/// A holding can contain several people, therefore the user must select one
/// identity before continuing whenever the search produces multiple matches.
class ExistingPersonSearch extends StatefulWidget {
  const ExistingPersonSearch({
    super.key,
    required this.onConfirm,
    required this.repository,
  });

  final ValueChanged<List<Parcel>> onConfirm;
  final ParcelCatalogRepository repository;

  @override
  State<ExistingPersonSearch> createState() => _ExistingPersonSearchState();
}

class _ExistingPersonSearchState extends State<ExistingPersonSearch> {
  final TextEditingController _controller = TextEditingController();
  static const HoldingSearchService _searchService = HoldingSearchService();

  List<ExistingPersonCandidate> _candidates = const <ExistingPersonCandidate>[];
  String? _selectedGroupKey;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(final String query) {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _candidates = const <ExistingPersonCandidate>[];
        _selectedGroupKey = null;
        _searched = false;
      });
      return;
    }

    final List<ScoredParcel> matches = _searchService.searchByHoldingNumber(
      widget.repository.parcels,
      trimmed,
    );
    final List<ExistingPersonCandidate> candidates =
        buildExistingPersonCandidates(
      matchingParcels:
          matches.map((final ScoredParcel match) => match.parcel).toList(),
    );
    setState(() {
      _searched = true;
      _candidates = candidates;
      _selectedGroupKey =
          candidates.length == 1 ? candidates.single.groupKey : null;
    });
  }

  ExistingPersonCandidate? get _selectedCandidate {
    final String? groupKey = _selectedGroupKey;
    if (groupKey == null) return null;
    for (final ExistingPersonCandidate candidate in _candidates) {
      if (candidate.groupKey == groupKey) return candidate;
    }
    return null;
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final ExistingPersonCandidate? selected = _selectedCandidate;

    return ListView(
      padding:
          EdgeInsets.symmetric(horizontal: rw(16)).copyWith(bottom: rh(24)),
      children: <Widget>[
        verticalSpacing(16),
        CustomTextForm(
          hintText: 'holdings.add.search_holding_id_hint'.tr(),
          controller: _controller,
          isRTL: true,
          keyboardType: TextInputType.number,
          prefixIcon: Icon(Icons.search_rounded, color: colors.iconSecondary),
          onChanged: _search,
        ),
        verticalSpacing(16),
        if (_searched && _candidates.isEmpty)
          Text(
            'holdings.add.search_no_match'.tr(),
            style: AppTextStyles.font14Regular.copyWith(color: colors.textHint),
            textAlign: TextAlign.center,
          )
        else if (_candidates.isNotEmpty) ...<Widget>[
          if (_candidates.length > 1) ...<Widget>[
            Text(
              'holdings.add.select_holder'.tr(),
              style: AppTextStyles.font14SemiBold
                  .copyWith(color: colors.textPrimary),
              textAlign: TextAlign.right,
            ),
            verticalSpacing(8),
          ],
          for (final ExistingPersonCandidate candidate
              in _candidates) ...<Widget>[
            _HolderCandidateCard(
              candidate: candidate,
              selected: candidate.groupKey == _selectedGroupKey,
              onTap: () =>
                  setState(() => _selectedGroupKey = candidate.groupKey),
            ),
            verticalSpacing(8),
          ],
          verticalSpacing(8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary200,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: selected == null
                  ? null
                  : () => widget.onConfirm(selected.parcels),
              child: Text(
                'holdings.add.confirm_person'.tr(),
                style:
                    AppTextStyles.font14Bold.copyWith(color: AppColors.white),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HolderCandidateCard extends StatelessWidget {
  const _HolderCandidateCard({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final ExistingPersonCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final Color accent = selected ? AppColors.primary200 : colors.border;
    return Semantics(
      button: true,
      selected: selected,
      label: candidate.holderName,
      child: Material(
        color: selected
            ? AppColors.primary200.withValues(alpha: .08)
            : colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent, width: selected ? 1.5 : 1),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.person_outline_rounded,
                  color: selected ? AppColors.primary200 : colors.iconSecondary,
                ),
                horizontalSpacing(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        candidate.holderName,
                        style: AppTextStyles.font16SemiBold
                            .copyWith(color: colors.textPrimary),
                        textAlign: TextAlign.right,
                      ),
                      verticalSpacing(4),
                      Text(
                        '${'holdings.fields.national_id'.tr()}: ${candidate.nationalId}',
                        style: AppTextStyles.font12Regular
                            .copyWith(color: colors.textSecondary),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
                horizontalSpacing(8),
                Text(
                  'holdings.add.holder_parcel_count'.tr(
                    namedArgs: <String, String>{
                      'count': candidate.parcelCount.toString()
                    },
                  ),
                  style: AppTextStyles.font12Bold
                      .copyWith(color: colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
