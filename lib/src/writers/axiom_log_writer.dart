import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../json_safe.dart';
import '../log_writer.dart';

/// A [LogWriter] that prints structured JSON on the schema expected by
/// Axiom (and other standard-JSON ingest endpoints, e.g. BetterStack's
/// Logtail).
///
/// `payload` and `labels` are combined into a single `data` object, since
/// Axiom does not distinguish between metadata and payload attributes.
class AxiomLogWriter implements LogWriter {
  const AxiomLogWriter();

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
    final data = <String, dynamic>{...?payload, ...?labels};

    final entry = <String, dynamic>{
      '_time': timestamp.toUtc().toIso8601String(),
      'message': message,
      'level': severity.name,
      if (data.isNotEmpty) 'data': toJsonSafe(data),
      if (exception != null) 'exception': exception.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    };

    print(jsonEncode(entry));
  }
}
