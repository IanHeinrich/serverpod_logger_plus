import 'dart:async';
import 'dart:io';

import 'package:serverpod/serverpod.dart';

import 'log_writer.dart';

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

  LoggerPlus(
    this._session, {
    required LogWriter writer,
    Map<String, String>? labels,
    Map<String, dynamic>? payload,
    LogLevel? minimumLevel,
  })  : _writer = writer,
        _boundLabels = Map.unmodifiable(labels ?? const {}),
        _boundPayload = Map.unmodifiable(payload ?? const {}),
        _minimumLevel = minimumLevel;

  /// Labels currently bound to this logger.
  Map<String, String> get boundLabels => _boundLabels;

  /// Payload currently bound to this logger. This is merged into the payload
  /// of every log call made through this logger.
  Map<String, dynamic> get boundPayload => _boundPayload;

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
    );
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
    final mergedLabels = {..._boundLabels, ...?labels};
    final mergedPayload = {..._boundPayload, ...?payload};

    // The session log is always written; Serverpod applies its own log
    // settings to decide what reaches the database/Insights. The minimum
    // level here only gates this package's writer, so it can suppress
    // low-severity stdout noise (and its cost) without affecting Insights.
    _session.log(
      _flatten(message, labels: mergedLabels, payload: mergedPayload),
      level: severity,
      exception: exception,
      stackTrace: stackTrace,
    );

    final minimumLevel = _minimumLevel;
    if (minimumLevel != null && severity.index < minimumLevel.index) {
      return;
    }

    _dispatchToWriter(
      message,
      timestamp: timestamp,
      severity: severity,
      payload: mergedPayload.isEmpty ? null : mergedPayload,
      labels: mergedLabels.isEmpty ? null : mergedLabels,
      exception: exception,
      stackTrace: stackTrace,
    );
  }

  /// Sends an entry to the [LogWriter] without blocking the caller.
  ///
  /// A slow or network-bound writer must never add latency to the request
  /// that triggered the log call, so the write is fire-and-forget. Errors are
  /// caught here (rather than awaited) so a throwing writer can neither take
  /// down the request nor surface as an unhandled async error.
  void _dispatchToWriter(
    String message, {
    required DateTime timestamp,
    required LogLevel severity,
    Map<String, dynamic>? payload,
    Map<String, String>? labels,
    Object? exception,
    StackTrace? stackTrace,
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
      )
          .catchError((Object error, StackTrace writerStackTrace) {
        stderr
          ..writeln(
              '[serverpod_logger_plus] LogWriter threw while logging: $error')
          ..writeln(writerStackTrace.toString());
      }),
    );
  }

  String _flatten(
    String message, {
    required Map<String, String> labels,
    required Map<String, dynamic> payload,
  }) {
    String joinEntries(Map<dynamic, dynamic> map) =>
        map.entries.map((entry) => '${entry.key}=${entry.value}').join(', ');

    final buffer = StringBuffer(message);
    if (labels.isNotEmpty) {
      buffer.write(' | labels: ${joinEntries(labels)}');
    }
    if (payload.isNotEmpty) {
      buffer.write(' | payload: ${joinEntries(payload)}');
    }
    return buffer.toString();
  }
}
