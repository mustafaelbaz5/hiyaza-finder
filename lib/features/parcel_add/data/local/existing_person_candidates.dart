import '../../../parcel_catalog/data/model/parcel.dart';

/// One selectable person under a searched holding number. A holding number
/// may legitimately contain more than one person, so identity is the person
/// ID, then national ID, then holder name — never the holding number alone.
class ExistingPersonCandidate {
  const ExistingPersonCandidate({
    required this.groupKey,
    required this.parcels,
  });

  final String groupKey;
  final List<Parcel> parcels;

  Parcel get source => parcels.first;
  String get holderName => source.holderName?.trim().isNotEmpty == true
      ? source.holderName!.trim()
      : '—';
  String get nationalId => source.nationalId?.trim().isNotEmpty == true
      ? source.nationalId!.trim()
      : '—';
  int get parcelCount => parcels.length;
}

/// Builds one candidate per person identity from the holding-number matches.
/// All parcels for that person are retained so the add flow can inherit the
/// selected identity and ownership data from one consistent source.
List<ExistingPersonCandidate> buildExistingPersonCandidates({
  required final List<Parcel> matchingParcels,
}) {
  final Set<String> matchedPersonKeys =
      matchingParcels.map(_personIdentityKey).toSet();
  final List<ExistingPersonCandidate> candidates = matchedPersonKeys
      .map(
        (final String personKey) => ExistingPersonCandidate(
          groupKey: personKey,
          parcels: matchingParcels
              .where(
                (final Parcel parcel) =>
                    _personIdentityKey(parcel) == personKey,
              )
              .toList(growable: false),
        ),
      )
      .where(
        (final ExistingPersonCandidate candidate) =>
            candidate.parcels.isNotEmpty,
      )
      .toList()
    ..sort(
      (final ExistingPersonCandidate a, final ExistingPersonCandidate b) =>
          a.holderName.compareTo(b.holderName),
    );
  return candidates;
}

String _personIdentityKey(final Parcel parcel) {
  final String? personId = _nonEmpty(parcel.personId);
  if (personId != null) return 'person:$personId';

  final String? nationalId = _nonEmpty(parcel.nationalId);
  if (nationalId != null) return 'national:$nationalId';

  final String? holderName = _nonEmpty(parcel.holderName);
  if (holderName != null) {
    return 'holder:${holderName.toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}';
  }
  return 'parcel:${parcel.id}';
}

String? _nonEmpty(final String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
