import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/writer_test_helpers.dart';

void main() {
  group('Given an OtelJsonLogWriter', () {
    const writer = OtelJsonLogWriter();

    test(
      'when writing an info log with labels and payload, '
      'then it prints one OTLP/JSON LogRecord',
      () async {
        final json = await writeJson(
          writer,
          message: 'checkout completed',
          severity: LogLevel.info,
          payload: {'orderId': 'o-1', 'itemCount': 3},
          labels: {'service': 'checkout'},
        );

        expect(json['body'], {'stringValue': 'checkout completed'});
        expect(json['severityText'], 'INFO');
        expect(json['severityNumber'], 9);
        expect(int.parse(json['timeUnixNano'] as String), greaterThan(0));

        final attributes = otlpAttributes(json);
        expect(attributes['orderId'], {'stringValue': 'o-1'});
        expect(attributes['itemCount'], {'intValue': '3'});
        expect(attributes['service'], {'stringValue': 'checkout'});
      },
    );

    test(
      'when writing an error log with an exception, '
      'then exception.message, exception.type, and exception.stacktrace '
      'attributes are set',
      () async {
        final json = await writeJson(
          writer,
          message: 'payment failed',
          severity: LogLevel.error,
          exception: StateError('card declined'),
          stackTrace: StackTrace.current,
        );

        final attributes = otlpAttributes(json);
        expect(attributes['exception.message']['stringValue'],
            contains('card declined'));
        expect(attributes['exception.type']['stringValue'],
            contains('StateError'));
        expect(
            attributes['exception.stacktrace']['stringValue'], isA<String>());
      },
    );

    for (final entry in {
      LogLevel.debug: (5, 'DEBUG'),
      LogLevel.info: (9, 'INFO'),
      LogLevel.warning: (13, 'WARN'),
      LogLevel.error: (17, 'ERROR'),
      LogLevel.fatal: (21, 'FATAL'),
    }.entries) {
      test(
        'when severity is ${entry.key.name}, '
        'then severityNumber/severityText map to ${entry.value}',
        () async {
          final json = await writeJson(writer, severity: entry.key);
          expect(json['severityNumber'], entry.value.$1);
          expect(json['severityText'], entry.value.$2);
        },
      );
    }
  });
}
