import 'package:serverpod/serverpod.dart';

import '../log_writer.dart';

/// A [LogWriter] that fans a single log call out to several other writers.
///
/// Use this when one destination isn't enough - for example, to keep a
/// built-in structured-JSON writer for your log aggregator *and* run extra
/// work of your own on top (an async network push, a metrics counter, a
/// side-channel alert), without giving up the default output:
///
/// ```dart
/// ServerpodLoggerPlus.configure(
///   productionWriter: const MultiLogWriter([
///     GcpJsonLogWriter(),  // keep the default JSON on stdout
///     PagerDutyLogWriter(), // + your own async network call on errors
///   ]),
/// );
/// ```
///
/// Every writer is invoked for each log call. Writers are dispatched together
/// rather than one after another, so a slow writer doesn't hold up the others.
/// As with any [LogWriter], each one must not throw - a failure in one writer
/// is isolated so it can't stop the rest from running.
class MultiLogWriter implements FlushableLogWriter {
  /// The writers to dispatch every log call to, in the given order.
  final List<LogWriter> writers;

  /// Creates a [MultiLogWriter] that dispatches every log call to [writers].
  const MultiLogWriter(this.writers);

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
    await Future.wait([
      for (final writer in writers)
        Future(() => writer.write(
              message,
              severity: severity,
              timestamp: timestamp,
              payload: payload,
              labels: labels,
              exception: exception,
              stackTrace: stackTrace,
              traceId: traceId,
              spanId: spanId,
            )),
    ]);
  }

  @override
  Future<void> flush() async {
    await Future.wait([
      for (final writer in writers)
        if (writer is FlushableLogWriter) Future(() => writer.flush()),
    ]);
  }
}
