import 'package:serverpod/serverpod.dart';

const String maxDepthMarker = '[max depth exceeded]';

const int defaultJsonSafeMaxDepth = 16;

/// Recursively converts [value] into something [jsonEncode] can serialize.
///
/// Payloads and labels passed to a logger can contain arbitrary Dart values
/// (e.g. [DateTime], [UuidValue], enums, or custom model objects). A
/// [LogWriter] must never throw just because it was asked to log one of
/// these, so every structured writer runs its data through this function
/// before calling `jsonEncode`.
///
/// Cycles are broken by a depth cap, not by identity tracking: past [maxDepth]
/// levels a value becomes [maxDepthMarker], so a deeply nested but perfectly
/// acyclic subobject is collapsed too.
dynamic toJsonSafe(dynamic value, {int maxDepth = defaultJsonSafeMaxDepth}) =>
    _toJsonSafe(value, 0, maxDepth);

dynamic _toJsonSafe(dynamic value, int depth, int maxDepth) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is DateTime) return value.toIso8601String();
  if (value is UuidValue) return value.toString();

  if (value is Map) {
    if (depth >= maxDepth) return maxDepthMarker;
    return <String, dynamic>{
      for (final MapEntry<dynamic, dynamic> entry in value.entries)
        entry.key.toString(): _toJsonSafe(entry.value, depth + 1, maxDepth),
    };
  }
  if (value is Iterable) {
    if (depth >= maxDepth) return maxDepthMarker;
    return [
      for (final dynamic element in value)
        _toJsonSafe(element, depth + 1, maxDepth),
    ];
  }
  if (value is Enum) return value.name;

  if (depth >= maxDepth) return maxDepthMarker;
  try {
    // Support objects with a `toJson()` method that don't share a common
    // interface (e.g. generated Serverpod models).
    final dynamic result = value.toJson();
    return _toJsonSafe(result, depth + 1, maxDepth);
  } catch (_) {
    return value.toString();
  }
}
