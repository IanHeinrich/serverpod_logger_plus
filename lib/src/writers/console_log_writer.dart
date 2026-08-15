import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../json_safe.dart';
import '../log_writer.dart';

/// A [LogWriter] for local development.
///
/// Prints a single colored, human-readable line per log call, with an
/// optional pretty-printed JSON dump of the labels/payload underneath.
/// Intended for `runMode == development`, where a developer is watching the
/// terminal rather than a log aggregator.
class ConsoleLogWriter implements LogWriter {
  /// When true (the default), bound labels and payload are pretty-printed
  /// below the log line. Set to false for a more compact single-line output.
  final bool verbose;

  /// Creates a [ConsoleLogWriter].
  ///
  /// Set [verbose] to false for compact single-line output without the
  /// pretty-printed labels/payload dump.
  const ConsoleLogWriter({this.verbose = true});

  static const _jsonEncoder = JsonEncoder.withIndent('  ');

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
    final formattedTimestamp = _dim(timestamp.toIso8601String());
    final levelTag =
        '${_AnsiColors.forLevel(severity)}[${_levelLabel(severity)}]${_AnsiColors.reset}';

    final buffer = StringBuffer('$formattedTimestamp $levelTag $message');

    if (traceId != null) {
      final span = spanId != null ? ' span=$spanId' : '';
      buffer.write(_dim(' (trace=$traceId$span)'));
    }
    if (verbose && labels != null && labels.isNotEmpty) {
      buffer.write('\n${_dim('  Labels: ${_prettyJson(labels)}')}');
    }
    if (verbose && payload != null && payload.isNotEmpty) {
      buffer.write('\n${_dim('  Payload: ${_prettyJson(payload)}')}');
    }
    if (exception != null) {
      buffer.write(
          '\n${_AnsiColors.red}  Exception: $exception${_AnsiColors.reset}');
    }
    if (stackTrace != null) {
      buffer.write('\n${_dim(stackTrace.toString())}');
    }

    print(buffer.toString());
  }

  String _levelLabel(LogLevel level) => level.name.toUpperCase().padRight(7);

  String _dim(String text) => '${_AnsiColors.dim}$text${_AnsiColors.reset}';

  String _prettyJson(dynamic value) {
    try {
      return _jsonEncoder.convert(toJsonSafe(value));
    } catch (_) {
      return value.toString();
    }
  }
}

abstract final class _AnsiColors {
  static const reset = '\x1B[0m';
  static const red = '\x1B[31m';
  static const green = '\x1B[32m';
  static const yellow = '\x1B[33m';
  static const gray = '\x1B[90m';
  static const dim = '\x1B[2m';

  static String forLevel(LogLevel level) => switch (level) {
        LogLevel.debug => gray,
        LogLevel.info => green,
        LogLevel.warning => yellow,
        LogLevel.error || LogLevel.fatal => red,
      };
}
