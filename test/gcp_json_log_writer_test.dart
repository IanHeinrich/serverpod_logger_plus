import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/capture_print.dart';

void main() {
  group('Given a GcpJsonLogWriter', () {
    const writer = GcpJsonLogWriter();

    test(
      'when writing an info log with labels and payload, '
      'then it prints one JSON line matching the GCP schema',
      () async {
        final lines = await capturePrints(
          () => writer.write(
            'hello world',
            severity: LogLevel.info,
            timestamp: DateTime.now(),
            payload: {'durationMs': 42},
            labels: {'traceId': 'abc-123'},
          ),
        );

        expect(lines, hasLength(1));
        final json = jsonDecode(lines.single) as Map<String, dynamic>;

        expect(json['message'], 'hello world');
        expect(json['severity'], 'INFO');
        expect(DateTime.parse(json['time'] as String).isUtc, isTrue);
        expect(json['logging.googleapis.com/labels'], {'traceId': 'abc-123'});
        expect(json['payload'], {'durationMs': 42});
      },
    );

    test(
      'when writing a fatal log with an exception and stack trace, '
      'then severity maps to CRITICAL and both are attached as strings',
      () async {
        final lines = await capturePrints(
          () => writer.write(
            'boom',
            severity: LogLevel.fatal,
            timestamp: DateTime.now(),
            exception: StateError('bad state'),
            stackTrace: StackTrace.current,
          ),
        );

        final json = jsonDecode(lines.single) as Map<String, dynamic>;
        expect(json['severity'], 'CRITICAL');
        expect(json['exception'], contains('bad state'));
        expect(json['stackTrace'], isA<String>());
      },
    );

    test(
      'when no labels or payload are provided, '
      'then those keys are omitted entirely',
      () async {
        final lines = await capturePrints(
          () => writer.write('quiet log',
              severity: LogLevel.debug, timestamp: DateTime.now()),
        );

        final json = jsonDecode(lines.single) as Map<String, dynamic>;
        expect(json.containsKey('logging.googleapis.com/labels'), isFalse);
        expect(json.containsKey('payload'), isFalse);
      },
    );

    for (final entry in {
      LogLevel.debug: 'DEBUG',
      LogLevel.info: 'INFO',
      LogLevel.warning: 'WARNING',
      LogLevel.error: 'ERROR',
      LogLevel.fatal: 'CRITICAL',
    }.entries) {
      test(
        'when severity is ${entry.key}, then it maps to GCP severity ${entry.value}',
        () async {
          final lines = await capturePrints(
            () => writer.write('msg',
                severity: entry.key, timestamp: DateTime.now()),
          );
          final json = jsonDecode(lines.single) as Map<String, dynamic>;
          expect(json['severity'], entry.value);
        },
      );
    }
  });
}
