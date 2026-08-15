import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/capture_print.dart';

void main() {
  group('Given a GenericJsonLogWriter', () {
    const writer = GenericJsonLogWriter();

    test(
      'when writing a warning log with labels and payload, '
      'then it prints one flat JSON line',
      () async {
        final lines = await capturePrints(
          () => writer.write(
            'disk usage high',
            severity: LogLevel.warning,
            timestamp: DateTime.now(),
            payload: {'usagePercent': 91},
            labels: {'host': 'web-1'},
          ),
        );

        expect(lines, hasLength(1));
        final json = jsonDecode(lines.single) as Map<String, dynamic>;

        expect(json['message'], 'disk usage high');
        expect(json['level'], 'WARNING');
        expect(DateTime.parse(json['timestamp'] as String).isUtc, isTrue);
        expect(json['labels'], {'host': 'web-1'});
        expect(json['payload'], {'usagePercent': 91});
      },
    );

    test(
      'when writing an error log with an exception, '
      'then exception and stackTrace are attached as strings',
      () async {
        final lines = await capturePrints(
          () => writer.write(
            'request failed',
            severity: LogLevel.error,
            timestamp: DateTime.now(),
            exception: ArgumentError('bad arg'),
            stackTrace: StackTrace.current,
          ),
        );

        final json = jsonDecode(lines.single) as Map<String, dynamic>;
        expect(json['exception'], contains('bad arg'));
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
        expect(json.containsKey('labels'), isFalse);
        expect(json.containsKey('payload'), isFalse);
      },
    );
  });
}
