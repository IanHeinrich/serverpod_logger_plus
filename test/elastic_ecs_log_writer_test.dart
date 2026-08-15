import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/capture_print.dart';

void main() {
  group('Given an ElasticEcsLogWriter', () {
    const writer = ElasticEcsLogWriter();

    test(
      'when writing an info log with labels and payload, '
      'then it prints one JSON line matching the ECS schema',
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
        expect(json['log.level'], 'info');
        expect(DateTime.parse(json['@timestamp'] as String).isUtc, isTrue);
        expect(json['labels'], {'service': 'checkout'});
        expect(json['payload'], {'orderId': 'o-1'});
      },
    );

    test(
      'when writing an error log with an exception, '
      'then error.message, error.type, and error.stack_trace are set',
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
        expect(json['error.message'], contains('card declined'));
        expect(json['error.type'], contains('StateError'));
        expect(json['error.stack_trace'], isA<String>());
      },
    );

    for (final entry in {
      LogLevel.debug: 'debug',
      LogLevel.info: 'info',
      LogLevel.warning: 'warn',
      LogLevel.error: 'error',
      LogLevel.fatal: 'fatal',
    }.entries) {
      test(
        'when severity is ${entry.key}, then log.level maps to ${entry.value}',
        () async {
          final lines = await capturePrints(
            () => writer.write('msg',
                severity: entry.key, timestamp: DateTime.now()),
          );
          final json = jsonDecode(lines.single) as Map<String, dynamic>;
          expect(json['log.level'], entry.value);
        },
      );
    }
  });
}
