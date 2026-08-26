import 'dart:convert';

import 'json_safe.dart';

/// Default per-value cap applied to the flattened session-log string. 1024
/// matches Elasticsearch's `ignore_above` default for keyword fields.
const int defaultFlattenValueMaxLength = 1024;

/// Hard cap on the whole flattened line, independent of the per-value cap.
const int defaultFlattenTotalMaxLength = 8192;

/// Builds the single human-readable string handed to `Session.log`.
///
/// A truncated value is no longer valid JSON - this line is for humans reading
/// Serverpod Insights, not for a parser.
String flattenLogMessage(
  String message, {
  required Map<String, String> labels,
  required Map<String, dynamic> payload,
  int valueMaxLength = defaultFlattenValueMaxLength,
  int totalMaxLength = defaultFlattenTotalMaxLength,
}) {
  String joinEntries(Map<String, dynamic> map) => map.entries
      .map((entry) =>
          '${entry.key}=${_truncate(stringifyLogValue(entry.value), valueMaxLength)}')
      .join(', ');

  final buffer = StringBuffer(message);
  if (labels.isNotEmpty) {
    buffer.write(' | labels: ${joinEntries(labels)}');
  }
  if (payload.isNotEmpty) {
    buffer.write(' | payload: ${joinEntries(payload)}');
  }
  return _truncate(buffer.toString(), totalMaxLength);
}

/// Renders [value] as a single-line, unambiguous string. Never throws.
String stringifyLogValue(Object? value) {
  try {
    final dynamic safe = toJsonSafe(value);
    if (safe is String) {
      return _needsQuoting(safe) ? jsonEncode(safe) : safe;
    }
    return jsonEncode(safe);
  } catch (_) {
    // jsonEncode throws JsonCyclicError on a cycle the depth cap did not
    // collapse, and a custom toJson() can return something unencodable.
    final text = _safeToString(value);
    return _needsQuoting(text) ? jsonEncode(text) : text;
  }
}

String _safeToString(Object? value) {
  try {
    return '$value';
  } catch (_) {
    return '[unprintable]';
  }
}

/// Whether [text] would corrupt the flattened format unless quoted.
///
/// `=` is deliberately excluded despite separating key from value: including it
/// would quote every URL with a query string. The first `=` in an entry is the
/// separator, later ones are data.
bool _needsQuoting(String text) {
  if (text.isEmpty) return true;
  if (text.trim().length != text.length) return true;
  for (final unit in text.codeUnits) {
    // ',' '|' '"' or any control character, which covers \n, \r and \t.
    if (unit == 0x2C || unit == 0x7C || unit == 0x22 || unit < 0x20) {
      return true;
    }
  }
  return false;
}

String _truncate(String text, int maxLength) {
  if (maxLength <= 0 || text.length <= maxLength) return text;

  // A lone high surrogate is invalid UTF-16 and would reach a database column.
  var end = maxLength;
  final lastUnit = text.codeUnitAt(end - 1);
  final isHighSurrogate = lastUnit >= 0xD800 && lastUnit <= 0xDBFF;
  if (isHighSurrogate) end -= 1;

  final dropped = text.length - end;
  return '${text.substring(0, end)}...[+$dropped chars]';
}
