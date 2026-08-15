import 'package:serverpod/serverpod.dart';

import 'log_writer.dart';
import 'trace_context.dart';

/// Global configuration for `serverpod_logger_plus`.
///
/// Call [ServerpodLoggerPlus.configure] once during server startup - before
/// any request accesses `session.logger` - to select which [LogWriter] is
/// used outside of local development (staging, production, test, or any
/// custom run mode).
abstract final class ServerpodLoggerPlus {
  static LogWriter? _productionWriter;
  static LogLevel? _minimumLevel;
  static bool _logRequests = false;
  static bool _bindTraceContext = false;
  static TraceContextExtractor? _traceContextExtractor;

  /// Sets the [LogWriter] used whenever `runMode != development`.
  ///
  /// [minimumLevel] gates this package's writer output: log calls below it
  /// are not written by the [LogWriter]. It does not affect Serverpod's own
  /// session log (which Serverpod filters via its log settings). `null` (the
  /// default) writes every level.
  ///
  /// When [logRequests] is `true`, every session that accesses
  /// `session.logger` emits one structured "request completed" record
  /// (endpoint, method, duration) when it closes, in addition to Serverpod's
  /// own database session log.
  ///
  /// When [bindTraceContext] is `true`, `session.logger` reads the incoming
  /// request's distributed-trace headers (W3C `traceparent`, GCP
  /// `X-Cloud-Trace-Context`, AWS `X-Amzn-Trace-Id`, or Datadog
  /// `x-datadog-trace-id`) and binds `traceId`/`spanId` as labels on every log
  /// call for that session. Pass [traceContextExtractor] to replace that
  /// built-in parsing with your own (e.g. for a proprietary trace header).
  static void configure({
    required LogWriter productionWriter,
    LogLevel? minimumLevel,
    bool logRequests = false,
    bool bindTraceContext = false,
    TraceContextExtractor? traceContextExtractor,
  }) {
    _productionWriter = productionWriter;
    _minimumLevel = minimumLevel;
    _logRequests = logRequests;
    _bindTraceContext = bindTraceContext;
    _traceContextExtractor = traceContextExtractor;
  }

  /// The minimum severity a log call must have for its [LogWriter] output to
  /// be emitted, or `null` to emit every level.
  static LogLevel? get minimumLevel => _minimumLevel;

  /// Whether each session should emit a structured request-completion log when
  /// it closes. Configured via [configure]'s `logRequests`.
  static bool get logRequests => _logRequests;

  /// Whether `session.logger` should bind trace context from request headers.
  /// Configured via [configure]'s `bindTraceContext`.
  static bool get bindTraceContext => _bindTraceContext;

  /// A custom trace-context extractor that replaces the built-in header
  /// parsing when set. Configured via [configure]'s `traceContextExtractor`.
  static TraceContextExtractor? get traceContextExtractor =>
      _traceContextExtractor;

  /// The configured production writer.
  ///
  /// Throws a [StateError] if [configure] has not been called yet. Failing
  /// fast here is preferable to silently guessing a cloud provider on the
  /// caller's behalf.
  static LogWriter get productionWriter {
    final writer = _productionWriter;
    if (writer == null) {
      throw StateError(
        'No production LogWriter configured for serverpod_logger_plus. Call '
        'ServerpodLoggerPlus.configure(productionWriter: ...) during server '
        'startup, before any session.logger is accessed.',
      );
    }
    return writer;
  }

  /// Drains the configured writer's in-flight work. Safe to call when no
  /// writer is configured, or when the writer doesn't ship logs
  /// asynchronously (both are no-ops), so it never fails a shutdown teardown.
  /// Call this from your server's shutdown path, before `pod.shutdown()`, if
  /// you use a [FlushableLogWriter] - the built-in writers are synchronous and
  /// have nothing to drain.
  static Future<void> flush() async {
    final writer = _productionWriter;
    if (writer is FlushableLogWriter) {
      await writer.flush();
    }
  }

  /// Clears the configured writer. Intended for tests.
  static void reset() {
    _productionWriter = null;
    _minimumLevel = null;
    _logRequests = false;
    _bindTraceContext = false;
    _traceContextExtractor = null;
  }
}
