import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../json_safe.dart';
import '../log_writer.dart';

/// A [LogWriter] that prints structured JSON that AWS CloudWatch Logs
/// natively parses.
///
/// CloudWatch treats any JSON object printed on a single line as a
/// structured log event and indexes its top-level keys as filterable
/// fields - just print JSON, nothing else to set up.
class CloudWatchJsonLogWriter implements LogWriter {
  const CloudWatchJsonLogWriter();

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
