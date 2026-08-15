import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../json_safe.dart';
import '../log_writer.dart';

/// A [LogWriter] that prints structured JSON on the Elastic Common Schema
/// (ECS), the field convention shared across the Elastic Stack (Elasticsearch,
/// Kibana, Filebeat) and Elastic Cloud.
///
/// Uses ECS reserved fields so a log line printed to stdout is picked up and
/// correctly indexed by Filebeat / Elastic Agent without a custom pipeline:
/// `@timestamp` is the event time, `log.level` drives the level facet,
/// `message` is the searchable body, and `error.message` / `error.type` /
/// `error.stack_trace` are recognized by Kibana's error views.
///
/// See: https://www.elastic.co/guide/en/ecs/current/index.html
class ElasticEcsLogWriter implements LogWriter {
  /// Creates an [ElasticEcsLogWriter].
  const ElasticEcsLogWriter();

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
      '@timestamp': timestamp.toUtc().toIso8601String(),
      'log.level': _level(severity),
      'message': message,
      // ECS reserved trace fields for APM log correlation.
      if (traceId != null) 'trace.id': traceId,
      if (spanId != null) 'span.id': spanId,
      // ECS `labels` must be a flat object of string key/values.
      if (labels != null && labels.isNotEmpty) 'labels': labels,
      if (payload != null && payload.isNotEmpty) 'payload': toJsonSafe(payload),
      if (exception != null) ...{
        'error.message': exception.toString(),
        'error.type': exception.runtimeType.toString(),
      },
      if (stackTrace != null) 'error.stack_trace': stackTrace.toString(),
    };

    print(jsonEncode(entry));
  }

  static String _level(LogLevel level) => switch (level) {
        LogLevel.debug => 'debug',
        LogLevel.info => 'info',
        LogLevel.warning => 'warn',
        LogLevel.error => 'error',
        LogLevel.fatal => 'fatal',
      };
}
