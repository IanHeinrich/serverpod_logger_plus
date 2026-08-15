import 'dart:io';

import 'package:serverpod/serverpod.dart';

import 'config.dart';
import 'log_writer.dart';
import 'logger.dart';
import 'writers/console_log_writer.dart';

final Expando<LoggerPlus> _loggersBySession =
    Expando<LoggerPlus>('serverpod_logger_plus');

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
    final existing = _loggersBySession[this];
    if (existing != null) return existing;

    final LogWriter writer;
    if (server.runMode == ServerpodRunMode.development) {
      writer = const ConsoleLogWriter();
    } else {
      writer = ServerpodLoggerPlus.productionWriter;
      _warnIfDoubleConsoleLoggingRisk();
    }

    final logger = LoggerPlus(
      this,
      writer: writer,
      minimumLevel: ServerpodLoggerPlus.minimumLevel,
    );
    _loggersBySession[this] = logger;
    return logger;
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
