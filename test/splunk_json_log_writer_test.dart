import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/capture_print.dart';

void main() {
  group('Given a SplunkJsonLogWriter', () {
    const writer = SplunkJsonLogWriter();

    test(
      'when writing an info log with labels and payload, '
      'then it prints one flat JSON line matching the Splunk schema',
      () async {
        final lines = await capturePrints(
          () => writer.write(
            'checkout completed',
            severity: LogLevel.info,
            timestamp: DateTime.now(),
            payload: {'orderId': 'o-1'},
            labels: {'service': 'checkout'},
          ),
        );

        expect(lines, hasLength(1));
        final json = jsonDecode(lines.single) as Map<String, dynamic>;

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
        final lines = await capturePrints(
          () => writer.write(
            'payment failed',
            severity: LogLevel.error,
            timestamp: DateTime.now(),
            exception: StateError('card declined'),
            stackTrace: StackTrace.current,
          ),
        );

        final json = jsonDecode(lines.single) as Map<String, dynamic>;
        expect(json['exception'], contains('card declined'));
        expect(json['stackTrace'], isA<String>());
      },
    );

    for (final entry in {
      LogLevel.debug: 'DEBUG',
      LogLevel.info: 'INFO',
      LogLevel.warning: 'WARNING',
      LogLevel.error: 'ERROR',
      LogLevel.fatal: 'FATAL',
    }.entries) {
      test(
        'when severity is ${entry.key}, then severity maps to ${entry.value}',
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
