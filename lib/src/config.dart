import 'package:serverpod/serverpod.dart';

import 'flatten.dart';
import 'log_writer.dart';
import 'redaction.dart';
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
  static int _flattenValueMaxLength = defaultFlattenValueMaxLength;
  static RedactionPolicy _redactionPolicy = RedactionPolicy.none;

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
  ///
  /// [flattenValueMaxLength] caps each individual label/payload value in the
  /// string written to Serverpod's session log. It does not affect the
  /// [LogWriter], which receives the untruncated structured data.
  ///
  /// [redactKeys] names label/payload keys whose values must never be logged.
  /// Matching is **case-insensitive**, applies at any nesting depth, and
  /// replaces the value with [redactionPlaceholder] (`[redacted]` by default).
  /// A matched key holding a map or list has the whole subtree replaced.
  ///
  /// [redactor] handles rules a key list cannot express. It runs *after*
  /// [redactKeys] and is never called for a key that already matched. Return
  /// the value it was given to leave it alone. It is also called with
  /// [exceptionRedactionKey] (`'exception'`) and a logged exception's
  /// `toString()` text, and what it returns is what both sinks receive as the
  /// error. See [RedactionPolicy] for what redaction does and does not cover.
  static void configure({
    required LogWriter productionWriter,
    LogLevel? minimumLevel,
    bool logRequests = false,
    bool bindTraceContext = false,
    TraceContextExtractor? traceContextExtractor,
    int flattenValueMaxLength = defaultFlattenValueMaxLength,
    Set<String> redactKeys = const <String>{},
    Redactor? redactor,
    String redactionPlaceholder = defaultRedactionPlaceholder,
  }) {
    _productionWriter = productionWriter;
    _minimumLevel = minimumLevel;
    _logRequests = logRequests;
    _bindTraceContext = bindTraceContext;
    _traceContextExtractor = traceContextExtractor;
    _flattenValueMaxLength = flattenValueMaxLength;
    _redactionPolicy = RedactionPolicy(
      keys: redactKeys,
      redactor: redactor,
      placeholder: redactionPlaceholder,
    );
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

  /// Per-value cap applied when flattening labels/payload into the string sent
  /// to Serverpod's session log.
  static int get flattenValueMaxLength => _flattenValueMaxLength;

  /// The redaction rules applied to labels and payload before either sink
  /// sees them.
  static RedactionPolicy get redactionPolicy => _redactionPolicy;

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
    _flattenValueMaxLength = defaultFlattenValueMaxLength;
    _redactionPolicy = RedactionPolicy.none;
  }
}
