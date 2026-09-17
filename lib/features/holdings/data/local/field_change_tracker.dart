import 'package:flutter/foundation.dart' show listEquals;

/// Compares a field's current value against its original value to decide
/// whether it should show the "modified" indicator — one generic
/// comparison instead of duplicating `current != original` at every field
/// in every edit screen.
///
/// Delegates to `==` for every field type already stored on `Parcel`
/// (`String?`, `double?`, `bool`), which have correct value equality via
/// Dart's default `==`. `List` fields (`notes`) are the one exception —
/// `copyWith` always creates a new list instance, so a plain `!=` would
/// compare by reference and always report "modified" even when the
/// contents are identical; `listEquals` compares element-by-element
/// instead.
class FieldChangeTracker {
  const FieldChangeTracker._();

  /// `true` if [current] differs from [original] — the two values must be
  /// the same field pulled from a "before edits" and "current" record.
  static bool isModified<T>(final T current, final T original) {
    if (current is List && original is List) {
      return !listEquals(current, original);
    }
    return current != original;
  }
}
