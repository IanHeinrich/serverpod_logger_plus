import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/writer_test_helpers.dart';

void main() {
  group('Given a GenericJsonLogWriter', () {
    const writer = GenericJsonLogWriter();

    test(
      'when writing a warning log with labels and payload, '
      'then it prints one flat JSON line',
      () async {
        final json = await writeJson(
          writer,
          message: 'disk usage high',
          severity: LogLevel.warning,
          payload: {'usagePercent': 91},
          labels: {'host': 'web-1'},
        );

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
        final json = await writeJson(
          writer,
          message: 'request failed',
          severity: LogLevel.error,
          exception: ArgumentError('bad arg'),
          stackTrace: StackTrace.current,
        );

        expect(json['exception'], contains('bad arg'));
        expect(json['stackTrace'], isA<String>());
      },
    );

    test(
      'when no labels or payload are provided, '
      'then those keys are omitted entirely',
      () async {
        final json = await writeJson(writer,
            message: 'quiet log', severity: LogLevel.debug);

        expect(json.containsKey('labels'), isFalse);
        expect(json.containsKey('payload'), isFalse);
      },
    );
  });
}
