import 'package:serverpod/serverpod.dart';

/// Recursively converts [value] into something [jsonEncode] can serialize.
///
/// Payloads and labels passed to a logger can contain arbitrary Dart values
/// (e.g. [DateTime], [UuidValue], enums, or custom model objects). A
/// [LogWriter] must never throw just because it was asked to log one of
/// these, so every structured writer runs its data through this function
/// before calling `jsonEncode`.
dynamic toJsonSafe(dynamic value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is DateTime) return value.toIso8601String();
  if (value is UuidValue) return value.toString();
  if (value is Map) {
    return value.map(
        (dynamic key, dynamic v) => MapEntry(key.toString(), toJsonSafe(v)));
  }
  if (value is Iterable) {
    return value.map(toJsonSafe).toList();
  }
  if (value is Enum) return value.name;

  try {
    // Support objects with a `toJson()` method that don't share a common
    // interface (e.g. generated Serverpod models).
    final dynamic result = value.toJson();
    return toJsonSafe(result);
  } catch (_) {
    return value.toString();
  }
}
