import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/writer_test_helpers.dart';

void main() {
  group('Given a DatadogJsonLogWriter', () {
    const writer = DatadogJsonLogWriter();

    test(
      'when writing an info log with labels and payload, '
      'then it prints one JSON line matching the Datadog schema',
      () async {
        final json = await writeJson(
          writer,
          message: 'checkout completed',
          severity: LogLevel.info,
          payload: {'orderId': 'o-1'},
          labels: {'service': 'checkout'},
        );

        expect(json['message'], 'checkout completed');
        expect(json['status'], 'info');
        expect(DateTime.parse(json['@timestamp'] as String).isUtc, isTrue);
        expect(json['labels'], {'service': 'checkout'});
        expect(json['payload'], {'orderId': 'o-1'});
      },
    );

    test(
      'when writing an error log with an exception, '
      'then error.message, error.kind, and error.stack are set for Error Tracking',
      () async {
        final json = await writeJson(
          writer,
          message: 'payment failed',
          severity: LogLevel.error,
          exception: StateError('card declined'),
          stackTrace: StackTrace.current,
        );

        expect(json['error.message'], contains('card declined'));
        expect(json['error.kind'], contains('StateError'));
        expect(json['error.stack'], isA<String>());
      },
    );

    testSeverityMapping(
      writer,
      field: 'status',
      expected: {
        LogLevel.debug: 'debug',
        LogLevel.info: 'info',
        LogLevel.warning: 'warn',
        LogLevel.error: 'error',
        LogLevel.fatal: 'fatal',
      },
    );
  });
}
