/// نوع الاستخدام — APP_UPDATES_CLAUDE.md § 4.1. [Parcel.usageType] keeps
/// storing the Arabic label as a plain `String` (this codebase's convention
/// for every other option field — `creditType`/`reformType`/`cropType`);
/// this enum is a typed view over that string used only where the
/// conditional-field and bidirectional-note logic needs to switch
/// exhaustively instead of comparing raw Arabic literals everywhere.
enum UsageType {
  agricultural('زراعة'),
  buildings('مباني'),
  fallow('بور');

  const UsageType(this.label);

  /// The exact Arabic string stored on [Parcel.usageType].
  final String label;

  static UsageType fromLabel(final String? label) => UsageType.values.firstWhere(
        (final UsageType t) => t.label == label,
        orElse: () => UsageType.agricultural,
      );
}
