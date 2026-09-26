/// Pure rules for identifying a parcel's logical holding/person group.
///
/// A literal holding number of zero is a deliberate "غير محيز" value. It
/// must not make every zero-valued parcel in a city one giant holding, so the
/// local person identity is preferred and the holder name is only a fallback.
class ParcelHoldingIdentity {
  const ParcelHoldingIdentity._();

  static String groupKey({
    required final String id,
    required final String holdingId,
    final String? personId,
    final String? pendingGroupId,
    final String? holderName,
  }) {
    final String trimmedHoldingId = holdingId.trim();
    if (trimmedHoldingId == '0') {
      final String? person = _clean(personId);
      if (person != null) return 'zero-person:$person';

      final String? holder = _normalizeHolderName(holderName);
      if (holder != null) return 'zero-holder:$holder';

      return 'zero-parcel:$id';
    }

    final bool pending = trimmedHoldingId.isEmpty ||
        trimmedHoldingId == '-' ||
        trimmedHoldingId == '-1';
    if (pending) {
      return 'pending:${personId ?? pendingGroupId ?? id}';
    }

    // Keep the established raw holding-id key for imported/confirmed data.
    return holdingId;
  }

  static String? _clean(final String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _normalizeHolderName(final String? value) {
    final String? cleaned = _clean(value);
    if (cleaned == null) return null;
    return cleaned.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
