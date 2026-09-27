import '../../../parcel_catalog/data/model/parcel.dart';

/// Creates the editable shape for a new parcel belonging to an existing
/// person. Identity and ownership markers remain intact; parcel-specific
/// survey data starts fresh.
Parcel existingPersonParcelTemplate(final Parcel source) => source.copyWith(
      landNumber: '0',
      feddan: null,
      qirat: null,
      sahm: null,
      totalSqm: null,
      basinName: null,
      basinCode: null,
      cropType: null,
      growthStages: null,
      usageType: Parcel.defaultUsageType,
      completedAt: null,
      completedBy: null,
      holdingsCount: (source.holdingsCount ?? 1) + 1,
      // Ordinary notes describe the source parcel, not the new one. The
      // delegate marker is retained because it describes the person/owner.
      notes: source.notes
          .where((final String note) => note.startsWith('مفوض عنه'))
          .toList(),
    );
