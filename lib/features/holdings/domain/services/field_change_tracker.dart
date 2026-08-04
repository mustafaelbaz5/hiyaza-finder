/// Compares a field's current value against its original value to decide
/// whether it should show the "تم التعديل" (modified) indicator — one
/// generic comparison instead of duplicating `current != original` at
/// every field in every edit screen.
///
/// Deliberately trivial (delegates to `==`) rather than field-type-aware:
/// every field type already stored on [Parcel] (`String?`, `double?`,
/// `bool`) has correct value equality via Dart's default `==`, so no
/// per-type branching is needed. Kept as its own named concept (rather
/// than inlining `!=` at each call site) so the *meaning* — "is this field
/// modified in this edit session" — reads clearly at each `FieldRow`, and
/// so the rule has one place to change if it ever needs to (e.g. treating
/// `''` and `null` as equal).
class FieldChangeTracker {
  const FieldChangeTracker._();

  /// `true` if [current] differs from [original] — the two values must be
  /// the same field pulled from a "before edits" and "current" record.
  static bool isModified<T>(final T current, final T original) => current != original;
}
