import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../json_safe.dart';
import '../log_writer.dart';

/// A [LogWriter] that prints structured JSON on the schema expected by
/// Datadog Log Management.
///
/// Uses Datadog's reserved attributes so logs are parsed without a custom
/// pipeline: `message` is indexed for full text search, `status` drives the
/// severity facet, `@timestamp` is the default date attribute, and
/// `error.message` / `error.stack` / `error.kind` are picked up automatically
/// by Error Tracking.
///
/// See: https://docs.datadoghq.com/logs/log_configuration/attributes_naming_convention/
class DatadogJsonLogWriter implements LogWriter {
  /// Creates a [DatadogJsonLogWriter].
  const DatadogJsonLogWriter();

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
      'message': message,
      'status': _status(severity),
      '@timestamp': timestamp.toUtc().toIso8601String(),
      // Datadog trace-correlation attributes. Datadog expects 64-bit decimal
      // ids; these pass through as received, so they link when the incoming
      // trace header is Datadog's own.
      if (traceId != null) 'dd.trace_id': traceId,
      if (spanId != null) 'dd.span_id': spanId,
      if (labels != null && labels.isNotEmpty) 'labels': labels,
      if (payload != null && payload.isNotEmpty) 'payload': toJsonSafe(payload),
      if (exception != null) ...{
        'error.message': exception.toString(),
        'error.kind': exception.runtimeType.toString(),
      },
      if (stackTrace != null) 'error.stack': stackTrace.toString(),
    };

    print(jsonEncode(entry));
  }

  static String _status(LogLevel level) => switch (level) {
        LogLevel.debug => 'debug',
        LogLevel.info => 'info',
        LogLevel.warning => 'warn',
        LogLevel.error => 'error',
        LogLevel.fatal => 'fatal',
      };
}
