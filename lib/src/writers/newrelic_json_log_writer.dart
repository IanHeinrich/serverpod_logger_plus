import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../json_safe.dart';
import '../log_writer.dart';

/// A [LogWriter] that prints structured JSON that New Relic's log forwarders
/// (the infrastructure agent, Fluent Bit, Kubernetes plugin, etc.) collect
/// from stdout and send to New Relic Logs.
///
/// New Relic parses top-level JSON attributes automatically: `message` is the
/// indexed log body, `timestamp` sets the event time, `level` is the
/// conventional log-level attribute, and `error.message` / `error.class` /
/// `error.stack` line up with New Relic's error attributes.
///
/// See: https://docs.newrelic.com/docs/logs/log-api/introduction-log-api/
class NewRelicJsonLogWriter implements LogWriter {
  /// Creates a [NewRelicJsonLogWriter].
  const NewRelicJsonLogWriter();

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
      'timestamp': timestamp.toUtc().toIso8601String(),
      'message': message,
      'level': severity.name,
      // New Relic logs-in-context reserved trace fields.
      if (traceId != null) 'trace.id': traceId,
      if (spanId != null) 'span.id': spanId,
      if (labels != null && labels.isNotEmpty) 'labels': labels,
      if (payload != null && payload.isNotEmpty) 'payload': toJsonSafe(payload),
      if (exception != null) ...{
        'error.message': exception.toString(),
        'error.class': exception.runtimeType.toString(),
      },
      if (stackTrace != null) 'error.stack': stackTrace.toString(),
    };

    print(jsonEncode(entry));
  }
}
