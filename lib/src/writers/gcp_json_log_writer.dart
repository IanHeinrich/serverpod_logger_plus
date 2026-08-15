import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../json_safe.dart';
import '../log_writer.dart';

/// A [LogWriter] that prints structured JSON on the schema expected by
/// Google Cloud Logging (Cloud Run, GKE, App Engine, Compute Engine, etc).
///
/// The GCP logging agent automatically parses `severity`, `time`, and the
/// `logging.googleapis.com/labels` key from a JSON log line printed to
/// stdout - no client library or network call is required.
///
/// See: https://cloud.google.com/logging/docs/structured-logging
class GcpJsonLogWriter implements LogWriter {
  /// Creates a [GcpJsonLogWriter].
  const GcpJsonLogWriter();

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
      'severity': _severity(severity),
      'time': timestamp.toUtc().toIso8601String(),
      if (labels != null && labels.isNotEmpty)
        'logging.googleapis.com/labels': labels,
      if (payload != null && payload.isNotEmpty) 'payload': toJsonSafe(payload),
      if (exception != null) 'exception': exception.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    };

    print(jsonEncode(entry));
  }

  static String _severity(LogLevel level) => switch (level) {
        LogLevel.debug => 'DEBUG',
        LogLevel.info => 'INFO',
        LogLevel.warning => 'WARNING',
        LogLevel.error => 'ERROR',
        LogLevel.fatal => 'CRITICAL',
      };
}
