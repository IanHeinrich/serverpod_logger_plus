import 'dart:async';
import 'dart:io';

import 'package:serverpod/serverpod.dart';

import 'flatten.dart';
import 'log_severity.dart';
import 'log_writer.dart';
import 'redaction.dart';

/// The core structured logging engine.
///
/// Named `LoggerPlus` (rather than `Logger`) because `package:serverpod`
/// transitively exports a `Logger` class of its own (from `relic_core`, used
/// for HTTP request logging) - importing both under the same name would be
/// ambiguous in almost every Serverpod app.
///
/// A [LoggerPlus] is always bound to a Serverpod [Session]. Every log call is
/// dual-routed (the "Y-Splitter"):
///
///  - A flattened, human-readable string is sent to [Session.log], so it is
///    persisted to the Serverpod database and shows up in Serverpod Insights.
///  - The fully structured data (message, labels, payload, exception) is sent
///    to a [LogWriter], which is responsible for turning it into console
///    output or platform-specific structured JSON on stdout.
///
/// Use [bind] to attach contextual labels/payload (e.g. a trace id or
/// endpoint name) that will be included on every subsequent log call made
/// through the returned [LoggerPlus].
class LoggerPlus {
  final Session _session;
  final LogWriter _writer;
  final Map<String, String> _boundLabels;
  final Map<String, dynamic> _boundPayload;
  final LogLevel? _minimumLevel;
  final String? _traceId;
  final String? _spanId;
  final int _flattenValueMaxLength;
  final RedactionPolicy _redaction;
  bool _requestLoggingRegistered = false;

  LoggerPlus(
    this._session, {
    required LogWriter writer,
    Map<String, String>? labels,
    Map<String, dynamic>? payload,
    LogLevel? minimumLevel,
    String? traceId,
    String? spanId,
    int flattenValueMaxLength = defaultFlattenValueMaxLength,
    RedactionPolicy? redaction,
  })  : _writer = writer,
        _boundLabels = Map.unmodifiable(labels ?? const {}),
        _boundPayload = Map.unmodifiable(payload ?? const {}),
        _minimumLevel = minimumLevel,
        _traceId = traceId,
        _spanId = spanId,
        _flattenValueMaxLength = flattenValueMaxLength,
        _redaction = redaction ?? RedactionPolicy.none;

  /// Labels currently bound to this logger.
  Map<String, String> get boundLabels => _boundLabels;

  /// Payload currently bound to this logger. This is merged into the payload
  /// of every log call made through this logger.
  Map<String, dynamic> get boundPayload => _boundPayload;

  /// Distributed-trace id bound to this logger, or null. Passed to the
  /// [LogWriter] on every log call so it can populate its reserved trace field.
  String? get traceId => _traceId;

  /// Distributed-trace span id bound to this logger, or null.
  String? get spanId => _spanId;

  /// Returns a new [LoggerPlus] with [labels] and [payload] merged on top of
  /// the context already bound to this logger. This logger is left unchanged.
  LoggerPlus bind(
      {Map<String, String>? labels, Map<String, dynamic>? payload}) {
    return LoggerPlus(
      _session,
      writer: _writer,
      labels: {..._boundLabels, ...?labels},
      payload: {..._boundPayload, ...?payload},
      minimumLevel: _minimumLevel,
      traceId: _traceId,
      spanId: _spanId,
      flattenValueMaxLength: _flattenValueMaxLength,
      redaction: _redaction,
    );
  }

  /// Emits one structured "request completed" record when this logger's
  /// [Session] closes: endpoint, method, and duration, dispatched to the
  /// [LogWriter] (and Serverpod's session log) like any other call. This
  /// bridges Serverpod's built-in database session log to your structured
  /// stdout sink; it does not know whether the call threw (the close hook
  /// isn't given the error), so keep using [error]/[fatal] in catch blocks
  /// for failures. Idempotent per logger instance.
  void logRequestOnClose() {
    if (_requestLoggingRegistered) return;
    _requestLoggingRegistered = true;
    _session.addWillCloseListener((session) {
      final method = session.method;
      return log(
        'Request completed',
        severity: LogLevel.info,
        labels: const {'event': 'request_completed'},
        payload: {
          'endpoint': session.endpoint,
          if (method != null) 'method': method,
          'durationMs': session.duration.inMilliseconds,
          'sessionId': session.sessionId.toString(),
        },
      );
    });
  }

  /// Logs a debug-level message.
  Future<void> debug(
    String message, {
    Map<String, dynamic>? payload,
    Map<String, String>? labels,
  }) =>
      log(message, severity: LogLevel.debug, payload: payload, labels: labels);

  /// Logs an info-level message.
  Future<void> info(
    String message, {
    Map<String, dynamic>? payload,
    Map<String, String>? labels,
  }) =>
      log(message, severity: LogLevel.info, payload: payload, labels: labels);

  /// Logs a warning-level message.
  Future<void> warning(
    String message, {
    Object? exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? payload,
    Map<String, String>? labels,
  }) =>
      log(
        message,
        severity: LogLevel.warning,
        payload: payload,
        labels: labels,
        exception: exception,
        stackTrace: stackTrace,
      );

  /// Logs an error-level message.
  Future<void> error(
    String message, {
    Object? exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? payload,
    Map<String, String>? labels,
  }) =>
      log(
        message,
        severity: LogLevel.error,
        payload: payload,
        labels: labels,
        exception: exception,
        stackTrace: stackTrace,
      );

  /// Logs a fatal-level message.
  Future<void> fatal(
    String message, {
    Object? exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? payload,
    Map<String, String>? labels,
  }) =>
      log(
        message,
        severity: LogLevel.fatal,
        payload: payload,
        labels: labels,
        exception: exception,
        stackTrace: stackTrace,
      );

  /// Logs [message] at the given [severity], dual-routing it to both
  /// Serverpod's session log and this logger's [LogWriter].
  Future<void> log(
    String message, {
    required LogLevel severity,
    Map<String, String>? labels,
    Map<String, dynamic>? payload,
    Object? exception,
    StackTrace? stackTrace,
  }) async {
    final timestamp = DateTime.now();
    final mergedLabels =
        _redaction.applyToLabels({..._boundLabels, ...?labels});
    final mergedPayload =
        _redaction.applyToPayload({..._boundPayload, ...?payload});
    final redactedException = _redaction.applyToException(exception);

    // The session log is always written; Serverpod applies its own log
    // settings to decide what reaches the database/Insights. The minimum
    // level here only gates this package's writer, so it can suppress
    // low-severity stdout noise (and its cost) without affecting Insights.
    _session.log(
      flattenLogMessage(
        message,
        labels: mergedLabels,
        payload: mergedPayload,
        valueMaxLength: _flattenValueMaxLength,
      ),
      level: severity,
      exception: redactedException,
      stackTrace: stackTrace,
    );

    final minimumLevel = _minimumLevel;
    if (minimumLevel != null &&
        logSeverityRank(severity) < logSeverityRank(minimumLevel)) {
      return;
    }

    _dispatchToWriter(
      message,
      timestamp: timestamp,
      severity: severity,
      payload: mergedPayload.isEmpty ? null : mergedPayload,
      labels: mergedLabels.isEmpty ? null : mergedLabels,
      exception: redactedException,
      stackTrace: stackTrace,
      traceId: _traceId,
      spanId: _spanId,
    );
  }

  /// Sends an entry to the [LogWriter] without blocking the caller.
  ///
  /// A slow or network-bound writer shouldn't add latency to the request
  /// that triggered the log call, so this is fire-and-forget. Errors are
  /// caught here instead of awaited, so a writer that throws can't crash the
  /// request or blow up as an unhandled async error.
  void _dispatchToWriter(
    String message, {
    required DateTime timestamp,
    required LogLevel severity,
    Map<String, dynamic>? payload,
    Map<String, String>? labels,
    Object? exception,
    StackTrace? stackTrace,
    String? traceId,
    String? spanId,
  }) {
    unawaited(
      _writer
          .write(
        message,
        timestamp: timestamp,
        severity: severity,
        payload: payload,
        labels: labels,
        exception: exception,
        stackTrace: stackTrace,
        traceId: traceId,
        spanId: spanId,
      )
          .catchError((Object error, StackTrace writerStackTrace) {
        stderr
          ..writeln(
              '[serverpod_logger_plus] LogWriter threw while logging: $error')
          ..writeln(writerStackTrace.toString());
      }),
    );
  }
}
