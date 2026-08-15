import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../json_safe.dart';
import '../log_writer.dart';

/// A [LogWriter] that prints a flat, provider-neutral JSON object per log
/// call: `message`, `level` (uppercase), `timestamp` (ISO 8601), and optional
/// `labels`, `payload`, `exception`, and `stackTrace` keys.
///
/// Use this for any platform that ingests a JSON line from stdout and indexes
/// its top-level keys as searchable fields, without requiring provider-specific
/// reserved field names. That includes, among others:
///
/// - **AWS CloudWatch Logs** - treats any single-line JSON object as a
///   structured event and indexes its top-level keys.
/// - **Azure Monitor / Container Insights** - captures the stdout line into
///   `ContainerLogV2`, where a JSON body is queryable as dynamic fields in KQL.
/// - Any log agent or collector configured to parse arbitrary stdout JSON
///   (Fluent Bit, Vector, Logstash, etc.).
///
/// If your platform has its own reserved schema (GCP, Datadog, Elastic, New
/// Relic, Splunk, OpenTelemetry), prefer that provider's dedicated writer so
/// severity facets, error grouping, and label filtering work out of the box.
class GenericJsonLogWriter implements LogWriter {
  /// Creates a [GenericJsonLogWriter].
  const GenericJsonLogWriter();

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
    final entry = <String, dynamic>{
      'message': message,
      'level': severity.name.toUpperCase(),
      'timestamp': timestamp.toUtc().toIso8601String(),
      if (labels != null && labels.isNotEmpty) 'labels': labels,
      if (payload != null && payload.isNotEmpty) 'payload': toJsonSafe(payload),
      if (exception != null) 'exception': exception.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    };

    print(jsonEncode(entry));
  }
}
