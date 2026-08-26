import 'dart:io';

import 'flatten.dart';

/// Replaces a value whose key matched, or that a [Redactor] rejected.
const String defaultRedactionPlaceholder = '[redacted]';

const String redactionMaxDepthMarker = '[max depth exceeded]';

/// Called with each label/payload key and value. Return a replacement, or
/// return the value itself to leave it alone - identity is how "no change" is
/// signalled, and only an unchanged value is walked into.
typedef Redactor = Object? Function(String key, Object? value);

/// Removes sensitive values from labels and payload before they are logged.
///
/// Applied once inside `LoggerPlus.log`, ahead of *both* sinks - the flattened
/// string sent to `Session.log` (and persisted to your database) and the
/// structured record sent to the [LogWriter].
///
/// Key matching is **case-insensitive**, since field casing varies in practice
/// (`Authorization` vs `authorization`) and a missed match leaks data.
///
/// This does **not** scan the log message, an exception's `toString()`, or the
/// stack trace. Scanning free text is false-positive-prone and is the caller's
/// responsibility.
final class RedactionPolicy {
  /// A policy that redacts nothing. Applying it returns the same map instance.
  static const RedactionPolicy none = RedactionPolicy._(
    keys: <String>{},
    redactor: null,
    placeholder: defaultRedactionPlaceholder,
  );

  /// Deepest nesting level the walk descends before substituting
  /// [redactionMaxDepthMarker]. Also what makes a cyclic payload terminate.
  static const int maxDepth = 8;

  const RedactionPolicy._({
    required this.keys,
    required this.redactor,
    required this.placeholder,
  });

  /// [keys] are lower-cased once here, not on every lookup.
  factory RedactionPolicy({
    Set<String> keys = const <String>{},
    Redactor? redactor,
    String placeholder = defaultRedactionPlaceholder,
  }) =>
      RedactionPolicy._(
        keys: {for (final key in keys) key.toLowerCase()},
        redactor: redactor,
        placeholder: placeholder,
      );

  /// Keys to redact, already lower-cased.
  final Set<String> keys;

  final Redactor? redactor;

  final String placeholder;

  bool get isNoop => keys.isEmpty && redactor == null;

  /// Redacts a payload, recursing into nested maps and lists.
  ///
  /// Copy-on-write: returns the argument itself when nothing matched.
  Map<String, dynamic> applyToPayload(Map<String, dynamic> payload) {
    if (isNoop || payload.isEmpty) return payload;

    Map<String, dynamic>? result;
    for (final entry in payload.entries) {
      final Object? redacted = _redactValue(entry.key, entry.value, 0);
      if (identical(redacted, entry.value)) continue;
      result ??= Map<String, dynamic>.of(payload);
      result[entry.key] = redacted;
    }
    return result ?? payload;
  }

  /// Redacts labels, which are flat and must stay `String`-valued.
  ///
  /// A [Redactor] returning a non-String has its result stringified, and one
  /// returning `null` **drops the label entirely** - there is no null slot in a
  /// `Map<String, String>`. A payload keeps a null, JSON null being meaningful
  /// there.
  Map<String, String> applyToLabels(Map<String, String> labels) {
    if (isNoop || labels.isEmpty) return labels;

    Map<String, String>? result;
    for (final entry in labels.entries) {
      final Object? redacted = _redactValue(entry.key, entry.value, 0);
      if (identical(redacted, entry.value)) continue;
      result ??= Map<String, String>.of(labels);
      if (redacted == null) {
        result.remove(entry.key);
      } else {
        result[entry.key] =
            redacted is String ? redacted : stringifyLogValue(redacted);
      }
    }
    return result ?? labels;
  }

  Object? _redactValue(String key, Object? value, int depth) {
    if (keys.contains(key.toLowerCase())) return placeholder;

    final Object? replaced = _applyRedactor(key, value);
    if (!identical(replaced, value)) return replaced;

    if (value is Map) {
      if (depth >= maxDepth) return redactionMaxDepthMarker;
      // Keys are only stringified for matching, never in the result: how a
      // value is finally represented is toJsonSafe's job, not redaction's.
      Map<dynamic, dynamic>? copy;
      for (final MapEntry<dynamic, dynamic> entry in value.entries) {
        final Object? redacted =
            _redactValue(entry.key.toString(), entry.value, depth + 1);
        if (identical(redacted, entry.value)) continue;
        copy ??= <dynamic, dynamic>{...value};
        copy[entry.key] = redacted;
      }
      return copy ?? value;
    }
    if (value is Iterable) {
      if (depth >= maxDepth) return redactionMaxDepthMarker;
      // Elements inherit the list's key, so a redactor may see it repeatedly.
      final elements = value.toList();
      List<dynamic>? copy;
      for (var i = 0; i < elements.length; i++) {
        final Object? redacted = _redactValue(key, elements[i], depth + 1);
        if (copy != null) {
          copy[i] = redacted;
        } else if (!identical(redacted, elements[i])) {
          copy = <dynamic>[...elements];
          copy[i] = redacted;
        }
      }
      return copy ?? value;
    }
    return value;
  }

  Object? _applyRedactor(String key, Object? value) {
    final redactor = this.redactor;
    if (redactor == null) return value;
    try {
      return redactor(key, value);
    } catch (error) {
      // Fail closed, and never name the value it failed on.
      stderr.writeln(
        '[serverpod_logger_plus] redactor threw for key "$key": $error',
      );
      return placeholder;
    }
  }
}
