import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/writer_test_helpers.dart';

void main() {
  group('Given a GcpJsonLogWriter', () {
    const writer = GcpJsonLogWriter();

    test(
      'when writing an info log with labels and payload, '
      'then it prints one JSON line matching the GCP schema',
      () async {
        final json = await writeJson(
          writer,
          message: 'hello world',
          severity: LogLevel.info,
          payload: {'durationMs': 42},
          labels: {'traceId': 'abc-123'},
        );

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
        final json = await writeJson(
          writer,
          message: 'boom',
          severity: LogLevel.fatal,
          exception: StateError('bad state'),
          stackTrace: StackTrace.current,
        );

        expect(json['severity'], 'CRITICAL');
        expect(json['exception'], contains('bad state'));
        expect(json['stackTrace'], isA<String>());
      },
    );

    test(
      'when no labels or payload are provided, '
      'then those keys are omitted entirely',
      () async {
        final json = await writeJson(writer,
            message: 'quiet log', severity: LogLevel.debug);

        expect(json.containsKey('logging.googleapis.com/labels'), isFalse);
        expect(json.containsKey('payload'), isFalse);
      },
    );

    testSeverityMapping(
      writer,
      field: 'severity',
      expected: {
        LogLevel.debug: 'DEBUG',
        LogLevel.info: 'INFO',
        LogLevel.warning: 'WARNING',
        LogLevel.error: 'ERROR',
        LogLevel.fatal: 'CRITICAL',
      },
    );
  });
}
