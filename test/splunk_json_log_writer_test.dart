import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/writer_test_helpers.dart';

void main() {
  group('Given a SplunkJsonLogWriter', () {
    const writer = SplunkJsonLogWriter();

    test(
      'when writing an info log with labels and payload, '
      'then it prints one flat JSON line matching the Splunk schema',
      () async {
        final json = await writeJson(
          writer,
          message: 'checkout completed',
          severity: LogLevel.info,
          payload: {'orderId': 'o-1'},
          labels: {'service': 'checkout'},
        );

        expect(json['message'], 'checkout completed');
        expect(json['severity'], 'INFO');
        expect(DateTime.parse(json['time'] as String).isUtc, isTrue);
        expect(json['labels'], {'service': 'checkout'});
        expect(json['payload'], {'orderId': 'o-1'});
      },
    );

    test(
      'when writing an error log with an exception, '
      'then exception and stackTrace are set',
      () async {
        final json = await writeJson(
          writer,
          message: 'payment failed',
          severity: LogLevel.error,
          exception: StateError('card declined'),
          stackTrace: StackTrace.current,
        );

        expect(json['exception'], contains('card declined'));
        expect(json['stackTrace'], isA<String>());
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
        LogLevel.fatal: 'FATAL',
      },
    );
  });
}
