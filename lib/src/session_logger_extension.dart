import 'dart:async';
import 'dart:io';

import 'package:serverpod/serverpod.dart';

import 'config.dart';
import 'log_writer.dart';
import 'logger.dart';
import 'trace_context.dart';
import 'writers/console_log_writer.dart';

final Expando<LoggerPlus> _loggersBySession =
    Expando<LoggerPlus>('serverpod_logger_plus');

/// Zone-value key for one [Session]'s scoped logger. Keyed per session because
/// several sessions can be live in the same zone.
final class _ScopedLoggerKey {
  const _ScopedLoggerKey(this.session);

  final Session session;

  @override
  bool operator ==(Object other) =>
      other is _ScopedLoggerKey && identical(other.session, session);

  @override
  int get hashCode => identityHashCode(session);
}

/// Mutable box so [SessionLoggerExtension.bindLogger] can re-point the logger
/// inside a scope. The box dies with the zone, so such a bind unwinds with it.
final class _LoggerScope {
  _LoggerScope(this.logger);

  LoggerPlus logger;
}

bool _hasWarnedAboutDoubleConsoleLogging = false;

/// Adds a zero-boilerplate `session.logger` getter to every Serverpod
/// [Session].
///
/// The returned [LoggerPlus] is created lazily and memoized per session. It
/// automatically detects `server.runMode`:
///
///  - `development`: a local ANSI [ConsoleLogWriter].
///  - anything else (`staging`, `production`, `test`, ...): the [LogWriter]
///    registered via [ServerpodLoggerPlus.configure].
extension SessionLoggerExtension on Session {
  LoggerPlus get logger {
    // Before the Expando, so a `runWithLogger` scope wins.
    final scope = Zone.current[_ScopedLoggerKey(this)];
    if (scope is _LoggerScope) return scope.logger;

    final existing = _loggersBySession[this];
    if (existing != null) return existing;

    final LogWriter writer;
    if (server.runMode == ServerpodRunMode.development) {
      writer = const ConsoleLogWriter();
    } else {
      writer = ServerpodLoggerPlus.productionWriter;
      _warnIfDoubleConsoleLoggingRisk();
    }

    final trace = ServerpodLoggerPlus.bindTraceContext
        ? (ServerpodLoggerPlus.traceContextExtractor ??
            extractTraceContext)(this)
        : const <String, String>{};
    final logger = LoggerPlus(
      this,
      writer: writer,
      minimumLevel: ServerpodLoggerPlus.minimumLevel,
      traceId: trace['traceId'],
      spanId: trace['spanId'],
      flattenValueMaxLength: ServerpodLoggerPlus.flattenValueMaxLength,
      redaction: ServerpodLoggerPlus.redactionPolicy,
    );
    _loggersBySession[this] = logger;
    if (ServerpodLoggerPlus.logRequests) {
      logger.logRequestOnClose();
    }
    return logger;
  }

  /// Enriches the memoized `session.logger` in place: every later
  /// `session.logger` on this [Session] returns a logger carrying [labels] and
  /// [payload], without threading the returned instance through your call
  /// stack. Unlike [LoggerPlus.bind] (which returns a new logger and leaves
  /// the receiver untouched), this re-points what `session.logger` resolves
  /// to for the rest of the request. Returns the enriched logger.
  ///
  /// There is no unbind. To end the enrichment with a block of work, use
  /// [runWithLogger]; calling this inside such a scope unwinds with it.
  LoggerPlus bindLogger({
    Map<String, String>? labels,
    Map<String, dynamic>? payload,
  }) {
    final bound = logger.bind(labels: labels, payload: payload);
    final scope = Zone.current[_ScopedLoggerKey(this)];
    if (scope is _LoggerScope) {
      scope.logger = bound;
    } else {
      _loggersBySession[this] = bound;
    }
    return bound;
  }

  /// Runs [body] with `session.logger` enriched by [labels] and [payload],
  /// then restores what `session.logger` resolved to before. Unlike
  /// [bindLogger], the enrichment ends with [body].
  ///
  /// The scope is carried by a [Zone], so it survives `await` and nests, and
  /// concurrent branches each see the scope they were started in.
  ///
  /// Work *started* inside the scope but not awaited keeps the scoped logger
  /// after this returns: the scope follows the asynchronous context, not the
  /// call.
  R runWithLogger<R>(
    R Function() body, {
    Map<String, String>? labels,
    Map<String, dynamic>? payload,
  }) {
    // Resolved before entering the new zone, so it builds on the current one.
    final scoped = logger.bind(labels: labels, payload: payload);
    return runZoned(
      body,
      zoneValues: {_ScopedLoggerKey(this): _LoggerScope(scoped)},
    );
  }

  /// Serverpod has its own built-in stdout writer for `session.log` calls
  /// (`sessionLogs.consoleEnabled` in the server config), independent of
  /// this package's [LogWriter]. If it's enabled alongside a configured
  /// production writer, every log call would be printed to stdout twice.
  void _warnIfDoubleConsoleLoggingRisk() {
    if (_hasWarnedAboutDoubleConsoleLogging) return;
    if (!serverpod.config.sessionLogs.consoleEnabled) return;

    _hasWarnedAboutDoubleConsoleLogging = true;
    stderr.writeln(
      '[serverpod_logger_plus] Warning: `sessionLogs.consoleEnabled` is true '
      'for run mode "${server.runMode}", so Serverpod\'s own built-in stdout '
      'log writer is active alongside this package\'s production LogWriter. '
      'Every session.log call will be printed to stdout twice. Set '
      '`sessionLogs: { consoleEnabled: false }` in this environment\'s '
      'config (or the SERVERPOD_SESSION_CONSOLE_LOG_ENABLED env var) to '
      'avoid duplicate logs, unless this is intentional.',
    );
  }
}
