import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'capture_print.dart';

/// Writes one log entry through [writer] and returns the single line it
/// printed, asserting that exactly one line was emitted.
///
/// [timestamp] defaults to `DateTime.now()`; pass one explicitly only when a
/// test asserts on the emitted time.
Future<String> writeLine(
  LogWriter writer, {
  String message = 'msg',
  required LogLevel severity,
  DateTime? timestamp,
  Map<String, dynamic>? payload,
  Map<String, String>? labels,
  Object? exception,
  StackTrace? stackTrace,
  String? traceId,
  String? spanId,
}) async {
  final lines = await capturePrints(
    () => writer.write(
      message,
      severity: severity,
      timestamp: timestamp ?? DateTime.now(),
      payload: payload,
      labels: labels,
      exception: exception,
      stackTrace: stackTrace,
      traceId: traceId,
      spanId: spanId,
    ),
  );
  expect(lines, hasLength(1));
  return lines.single;
}

/// Like [writeLine], but decodes the printed line as a JSON object.
Future<Map<String, dynamic>> writeJson(
  LogWriter writer, {
  String message = 'msg',
  required LogLevel severity,
  DateTime? timestamp,
  Map<String, dynamic>? payload,
  Map<String, String>? labels,
  Object? exception,
  StackTrace? stackTrace,
  String? traceId,
  String? spanId,
}) async {
  final line = await writeLine(
    writer,
    message: message,
    severity: severity,
    timestamp: timestamp,
    payload: payload,
    labels: labels,
    exception: exception,
    stackTrace: stackTrace,
    traceId: traceId,
    spanId: spanId,
  );
  return jsonDecode(line) as Map<String, dynamic>;
}

/// Registers one test per entry in [expected], asserting that writing at each
/// [LogLevel] sets [field] in the emitted JSON to the mapped value.
void testSeverityMapping(
  LogWriter writer, {
  required String field,
  required Map<LogLevel, Object> expected,
}) {
  expected.forEach((level, value) {
    test('when severity is ${level.name}, then $field is "$value"', () async {
      final json = await writeJson(writer, severity: level);
      expect(json[field], value);
    });
  });
}

/// Flattens an OTLP/JSON `LogRecord`'s `attributes` array into a
/// `key -> AnyValue` map for easy lookup in assertions.
Map<String, dynamic> otlpAttributes(Map<String, dynamic> record) {
  final attributes =
      (record['attributes'] as List).cast<Map<String, dynamic>>();
  return {for (final attr in attributes) attr['key'] as String: attr['value']};
}
