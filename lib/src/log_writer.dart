import 'package:serverpod/serverpod.dart';

/// Receives fully structured log data and writes it somewhere -
/// standard out as JSON for cloud log collectors, or a colored ANSI stream
/// for local development.
///
/// [LoggerPlus] dispatches `write` without waiting for it to complete, so a
/// slow or network-bound implementation never adds latency to the request
/// that triggered the log call. Implementations must not throw - a logging
/// failure should never take down the request it was trying to describe.
abstract class LogWriter {
  /// Writes a single log entry.
  ///
  /// [message] is the human-readable log message. [severity] is the log
  /// level. [timestamp] is the instant the log call was made (shared across
  /// every writer invoked for that call, so they agree on "when"). [payload]
  /// holds arbitrary structured data attached to this log call. [labels]
  /// holds string-only metadata typically used for filtering (trace ids,
  /// endpoint names, etc). [exception] and [stackTrace] are set when the log
  /// call is reporting an error. [traceId] and [spanId] carry distributed
  /// trace context when bound (see `bindTraceContext`); writers that have a
  /// reserved trace field should map them into it.
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
  });
}

/// Optional capability for a [LogWriter] that ships logs asynchronously (e.g.
/// a network push) and therefore has in-flight work to drain before the
/// process exits.
///
/// Most writers finish synchronously (they `print`) and don't need this. A
/// writer that buffers or awaits network I/O should implement this instead of
/// [LogWriter], track its own pending futures, and await them in [flush].
/// [ServerpodLoggerPlus.flush] drains any configured writer that implements
/// this; a plain [LogWriter] is skipped.
abstract class FlushableLogWriter implements LogWriter {
  /// Drains any in-flight writes. Call from your server's shutdown path via
  /// [ServerpodLoggerPlus.flush], before `pod.shutdown()`.
  Future<void> flush();
}
