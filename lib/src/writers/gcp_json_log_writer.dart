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
  /// The Google Cloud project id. When set, the reserved trace field is
  /// formatted as `projects/<projectId>/traces/<traceId>`. When null, the
  /// bare `<traceId>` is emitted instead, which Cloud Logging still correlates
  /// with Cloud Trace for logs written to stdout.
  final String? projectId;

  /// Creates a [GcpJsonLogWriter].
  ///
  /// [projectId] is optional; when omitted, the reserved trace field is still
  /// emitted (in bare form) so Logs Explorer and Trace Explorer can correlate
  /// log and trace data.
  const GcpJsonLogWriter({this.projectId});

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
      'severity': _severity(severity),
      'time': timestamp.toUtc().toIso8601String(),
      if (payload != null && payload.isNotEmpty) 'payload': toJsonSafe(payload),
      if (exception != null) 'exception': exception.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    };

    final hexSpanId = _hexSpanId(spanId);
    if (hexSpanId != null) entry['logging.googleapis.com/spanId'] = hexSpanId;
    if (traceId != null) {
      entry['logging.googleapis.com/trace'] =
          projectId != null ? 'projects/$projectId/traces/$traceId' : traceId;
    }
    if (labels != null && labels.isNotEmpty) {
      entry['logging.googleapis.com/labels'] = labels;
    }

    print(jsonEncode(entry));
  }

  /// Cloud Logging's `logging.googleapis.com/spanId` field expects a 16-char
  /// hex value, but `X-Cloud-Trace-Context` carries a decimal span id. Decimal
  /// ids are converted to zero-padded hex; values already in 16-char hex form
  /// (e.g. from a W3C `traceparent`) are passed through unchanged.
  static String? _hexSpanId(String? spanId) {
    if (spanId == null) return null;
    if (spanId.length == 16 && _isHex(spanId)) return spanId;
    final decimal = BigInt.tryParse(spanId);
    if (decimal != null) return decimal.toRadixString(16).padLeft(16, '0');
    return spanId;
  }

  static bool _isHex(String value) {
    for (final unit in value.codeUnits) {
      final isDigit = unit >= 0x30 && unit <= 0x39;
      final isLower = unit >= 0x61 && unit <= 0x66;
      final isUpper = unit >= 0x41 && unit <= 0x46;
      if (!isDigit && !isLower && !isUpper) return false;
    }
    return true;
  }

  static String _severity(LogLevel level) => switch (level) {
        LogLevel.debug => 'DEBUG',
        LogLevel.info => 'INFO',
        LogLevel.warning => 'WARNING',
        LogLevel.error => 'ERROR',
        LogLevel.fatal => 'CRITICAL',
      };
}
