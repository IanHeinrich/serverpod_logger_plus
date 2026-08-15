import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../json_safe.dart';
import '../log_writer.dart';

/// A [LogWriter] that prints flat structured JSON for Splunk.
///
/// When a Splunk forwarder (or the Splunk OpenTelemetry Collector) ingests
/// this stdout line with a JSON source type, Splunk extracts the top-level
/// keys as searchable fields: `time` sets the event timestamp, `severity` is
/// the level, and `message` is the event body.
///
/// This emits a flat JSON event rather than the HTTP Event Collector (HEC)
/// `{"event": {...}}` envelope, since that envelope is only required when
/// POSTing directly to the HEC endpoint - not when a forwarder collects
/// stdout.
///
/// See: https://docs.splunk.com/Documentation/Splunk/latest/Data/FormateventsforHTTPEventCollector
class SplunkJsonLogWriter implements LogWriter {
  /// Creates a [SplunkJsonLogWriter].
  const SplunkJsonLogWriter();

  @override
  Future<void> write(
    String message, {
    required LogLevel severity,
    required DateTime timestamp,
    Map<String, dynamic>? payload,
    Map<String, String>? labels,
    Object? exception,
    StackTrace? stackTrace,
    String? traceId,
    String? spanId,
  }) async {
    final entry = <String, dynamic>{
      'time': timestamp.toUtc().toIso8601String(),
      'severity': severity.name.toUpperCase(),
      'message': message,
      if (traceId != null) 'trace_id': traceId,
      if (spanId != null) 'span_id': spanId,
      if (labels != null && labels.isNotEmpty) 'labels': labels,
      if (payload != null && payload.isNotEmpty) 'payload': toJsonSafe(payload),
      if (exception != null) 'exception': exception.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    };

    print(jsonEncode(entry));
  }
}
