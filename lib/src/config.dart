import 'package:serverpod/serverpod.dart';

import 'log_writer.dart';

/// Global configuration for `serverpod_logger_plus`.
///
/// Call [ServerpodLoggerPlus.configure] once during server startup - before
/// any request accesses `session.logger` - to select which [LogWriter] is
/// used outside of local development (staging, production, test, or any
/// custom run mode).
abstract final class ServerpodLoggerPlus {
  static LogWriter? _productionWriter;
  static LogLevel? _minimumLevel;

  /// Sets the [LogWriter] used whenever `runMode != development`.
  ///
  /// [minimumLevel] gates this package's writer output: log calls below it
  /// are not written by the [LogWriter]. It does not affect Serverpod's own
  /// session log (which Serverpod filters via its log settings). `null` (the
  /// default) writes every level.
  static void configure({
    required LogWriter productionWriter,
    LogLevel? minimumLevel,
  }) {
    _productionWriter = productionWriter;
    _minimumLevel = minimumLevel;
  }

  /// The minimum severity a log call must have for its [LogWriter] output to
  /// be emitted, or `null` to emit every level.
  static LogLevel? get minimumLevel => _minimumLevel;

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

  /// Clears the configured writer. Intended for tests.
  static void reset() {
    _productionWriter = null;
    _minimumLevel = null;
  }
}
