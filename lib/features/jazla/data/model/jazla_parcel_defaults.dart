/// Values configured on a Jazla for parcels created after the configuration.
/// A null field means that Jazla does not provide a default for that field.
class JazlaParcelDefaults {
  const JazlaParcelDefaults({
    this.cropType,
    this.growthStages,
    this.usageType,
    this.notes,
    this.isInheritance,
  });

  final String? cropType;
  final String? growthStages;
  final String? usageType;
  final String? notes;
  final bool? isInheritance;

  bool get isEmpty =>
      cropType == null &&
      growthStages == null &&
      usageType == null &&
      notes == null &&
      isInheritance == null;

  static const Object _unset = Object();

  JazlaParcelDefaults copyWith({
    final Object? cropType = _unset,
    final Object? growthStages = _unset,
    final Object? usageType = _unset,
    final Object? notes = _unset,
    final Object? isInheritance = _unset,
  }) =>
      JazlaParcelDefaults(
        cropType:
            identical(cropType, _unset) ? this.cropType : cropType as String?,
        growthStages: identical(growthStages, _unset)
            ? this.growthStages
            : growthStages as String?,
        usageType: identical(usageType, _unset)
            ? this.usageType
            : usageType as String?,
        notes: identical(notes, _unset) ? this.notes : notes as String?,
        isInheritance: identical(isInheritance, _unset)
            ? this.isInheritance
            : isInheritance as bool?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cropType': cropType,
        'growthStages': growthStages,
        'usageType': usageType,
        'notes': notes,
        'isInheritance': isInheritance,
      };

  factory JazlaParcelDefaults.fromJson(final Map<String, dynamic> json) =>
      JazlaParcelDefaults(
        cropType: json['cropType'] as String?,
        growthStages: json['growthStages'] as String?,
        usageType: json['usageType'] as String?,
        notes: json['notes'] as String?,
        isInheritance: json['isInheritance'] as bool?,
      );

  @override
  bool operator ==(final Object other) =>
      other is JazlaParcelDefaults &&
      other.cropType == cropType &&
      other.growthStages == growthStages &&
      other.usageType == usageType &&
      other.notes == notes &&
      other.isInheritance == isInheritance;

  @override
  int get hashCode => Object.hash(
        cropType,
        growthStages,
        usageType,
        notes,
        isInheritance,
      );
}
