import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../json_safe.dart';
import '../log_writer.dart';

/// A [LogWriter] that prints a single OpenTelemetry log record encoded as
/// OTLP/JSON, following the OpenTelemetry Logs Data Model.
///
/// Each line is a `LogRecord` object: `timeUnixNano`, `severityNumber` and
/// `severityText` (mapped to the OTel severity ranges), a `body.stringValue`
/// holding the message, and an `attributes` array carrying `payload`, `labels`
/// and any exception details (as `exception.message` / `exception.type` /
/// `exception.stacktrace`, the OTel exception convention).
///
/// Note: a bare OTLP/JSON `LogRecord` printed to stdout is not itself a
/// turn-key ingestion path - it is intended to be collected by an
/// OpenTelemetry Collector whose pipeline maps these fields (e.g. a `filelog`
/// receiver with a JSON parser). If you just need a schema a specific vendor
/// ingests directly, prefer that vendor's writer.
///
/// See: https://opentelemetry.io/docs/specs/otel/logs/data-model/
class OtelJsonLogWriter implements LogWriter {
  /// Creates an [OtelJsonLogWriter].
  const OtelJsonLogWriter();

  @override
  Future<void> write(
    String message, {
    required LogLevel severity,
    required DateTime timestamp,
    Map<String, dynamic>? payload,
    Map<String, String>? labels,
    Object? exception,
    StackTrace? stackTrace,
  }) async {
    final attributes = <Map<String, dynamic>>[
      if (payload != null)
        for (final entry in payload.entries) _keyValue(entry.key, entry.value),
      if (labels != null)
        for (final entry in labels.entries) _keyValue(entry.key, entry.value),
      if (exception != null) ...[
        _keyValue('exception.message', exception.toString()),
        _keyValue('exception.type', exception.runtimeType.toString()),
      ],
      if (stackTrace != null)
        _keyValue('exception.stacktrace', stackTrace.toString()),
    ];

    final record = <String, dynamic>{
      'timeUnixNano': _unixNano(timestamp),
      'severityNumber': _severityNumber(severity),
      'severityText': _severityText(severity),
      'body': {'stringValue': message},
      if (attributes.isNotEmpty) 'attributes': attributes,
    };

    print(jsonEncode(record));
  }

  static String _unixNano(DateTime timestamp) =>
      (timestamp.toUtc().microsecondsSinceEpoch * 1000).toString();

  static Map<String, dynamic> _keyValue(String key, dynamic value) =>
      {'key': key, 'value': _anyValue(value)};

  /// Encodes an arbitrary Dart value as an OTLP/JSON `AnyValue`.
  static Map<String, dynamic> _anyValue(dynamic value) {
    final safe = toJsonSafe(value);
    if (safe is bool) return {'boolValue': safe};
    if (safe is int) return {'intValue': safe.toString()};
    if (safe is double) return {'doubleValue': safe};
    if (safe is List) {
      return {
        'arrayValue': {'values': safe.map(_anyValue).toList()},
      };
    }
    if (safe is Map) {
      return {
        'kvlistValue': {
          'values': [
            for (final entry in safe.entries)
              _keyValue(entry.key.toString(), entry.value),
          ],
        },
      };
    }
    return {'stringValue': safe?.toString() ?? ''};
  }

  static int _severityNumber(LogLevel level) => switch (level) {
        LogLevel.debug => 5,
        LogLevel.info => 9,
        LogLevel.warning => 13,
        LogLevel.error => 17,
        LogLevel.fatal => 21,
      };

  static String _severityText(LogLevel level) => switch (level) {
        LogLevel.debug => 'DEBUG',
        LogLevel.info => 'INFO',
        LogLevel.warning => 'WARN',
        LogLevel.error => 'ERROR',
        LogLevel.fatal => 'FATAL',
      };
}
