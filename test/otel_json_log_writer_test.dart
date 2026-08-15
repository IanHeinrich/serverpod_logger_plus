import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/capture_print.dart';

void main() {
  group('Given an OtelJsonLogWriter', () {
    const writer = OtelJsonLogWriter();

    test(
      'when writing an info log with labels and payload, '
      'then it prints one OTLP/JSON LogRecord',
      () async {
        final lines = await capturePrints(
          () => writer.write(
            'checkout completed',
            severity: LogLevel.info,
            timestamp: DateTime.now(),
            payload: {'orderId': 'o-1', 'itemCount': 3},
            labels: {'service': 'checkout'},
          ),
        );

        expect(lines, hasLength(1));
        final json = jsonDecode(lines.single) as Map<String, dynamic>;

        expect(json['body'], {'stringValue': 'checkout completed'});
        expect(json['severityText'], 'INFO');
        expect(json['severityNumber'], 9);
        expect(int.parse(json['timeUnixNano'] as String), greaterThan(0));

        final attributes =
            (json['attributes'] as List).cast<Map<String, dynamic>>();
        final byKey = {
          for (final attr in attributes) attr['key'] as String: attr['value'],
        };
        expect(byKey['orderId'], {'stringValue': 'o-1'});
        expect(byKey['itemCount'], {'intValue': '3'});
        expect(byKey['service'], {'stringValue': 'checkout'});
      },
    );

    test(
      'when writing an error log with an exception, '
      'then exception.message, exception.type, and exception.stacktrace '
      'attributes are set',
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
        final attributes =
            (json['attributes'] as List).cast<Map<String, dynamic>>();
        final byKey = {
          for (final attr in attributes)
            attr['key'] as String:
                (attr['value'] as Map<String, dynamic>)['stringValue'],
        };
        expect(byKey['exception.message'], contains('card declined'));
        expect(byKey['exception.type'], contains('StateError'));
        expect(byKey['exception.stacktrace'], isA<String>());
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
        'when severity is ${entry.key}, then severityNumber/severityText '
        'map to ${entry.value}',
        () async {
          final lines = await capturePrints(
            () => writer.write('msg',
                severity: entry.key, timestamp: DateTime.now()),
          );
          final json = jsonDecode(lines.single) as Map<String, dynamic>;
          expect(json['severityNumber'], entry.value.$1);
          expect(json['severityText'], entry.value.$2);
        },
      );
    }
  });
}
