/// Operational classification derived from a parcel's agricultural area.
///
/// Zero-area records are retained as useful reference data; this status only
/// controls presentation, counts, and filtering. It never changes storage.
enum ParcelActivityStatus {
  active,
  zeroArea,
}
