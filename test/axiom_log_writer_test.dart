import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/writer_test_helpers.dart';

void main() {
  group('Given an AxiomLogWriter', () {
    const writer = AxiomLogWriter();

    test(
      'when writing an info log with labels and payload, '
      'then payload and labels are merged into a single data object',
      () async {
        final json = await writeJson(
          writer,
          message: 'user signed up',
          severity: LogLevel.info,
          payload: {'userId': 'u-1'},
          labels: {'region': 'us-east'},
        );

        expect(json['message'], 'user signed up');
        expect(json['level'], 'info');
        expect(DateTime.parse(json['_time'] as String).isUtc, isTrue);
        expect(json['data'], {'userId': 'u-1', 'region': 'us-east'});
      },
    );

    test(
      'when no labels or payload are provided, '
      'then the data key is omitted entirely',
      () async {
        final json = await writeJson(writer,
            message: 'quiet log', severity: LogLevel.debug);

        expect(json.containsKey('data'), isFalse);
      },
    );

    test(
      'when writing a fatal log with an exception, '
      'then exception and stackTrace are attached as strings',
      () async {
        final json = await writeJson(
          writer,
          message: 'unrecoverable',
          severity: LogLevel.fatal,
          exception: StateError('bad'),
          stackTrace: StackTrace.current,
        );

        expect(json['level'], 'fatal');
        expect(json['exception'], contains('bad'));
        expect(json['stackTrace'], isA<String>());
      },
    );
  });
}
