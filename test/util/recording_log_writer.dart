import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';

/// One captured [LogWriter.write] call, with every argument retained.
class LoggedCall {
  LoggedCall({
    required this.message,
    required this.severity,
    required this.timestamp,
    this.payload,
    this.labels,
    this.exception,
    this.stackTrace,
    this.traceId,
    this.spanId,
  });

  final String message;
  final LogLevel severity;
  final DateTime timestamp;
  final Map<String, dynamic>? payload;
  final Map<String, String>? labels;
  final Object? exception;
  final StackTrace? stackTrace;
  final String? traceId;
  final String? spanId;
}

/// A [LogWriter] that records every call instead of printing.
class RecordingLogWriter implements LogWriter {
  final List<LoggedCall> calls = [];

  /// The single recorded call, asserting exactly one was made.
  LoggedCall get single {
    if (calls.length != 1) {
      throw StateError('Expected exactly 1 write call, got ${calls.length}');
    }
    return calls.single;
  }

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
    calls.add(LoggedCall(
      message: message,
      severity: severity,
      timestamp: timestamp,
      payload: payload,
      labels: labels,
      exception: exception,
      stackTrace: stackTrace,
      traceId: traceId,
      spanId: spanId,
    ));
  }
}

class RecordingFlushableLogWriter extends RecordingLogWriter
    implements FlushableLogWriter {
  int flushCount = 0;

  @override
  Future<void> flush() async => flushCount++;
}
