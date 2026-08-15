import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/capture_print.dart';

void main() {
  group('Given a ConsoleLogWriter', () {
    const writer = ConsoleLogWriter();

    test(
      'when writing an info log, '
      'then the line contains a green level tag and resets color',
      () async {
        final lines = await capturePrints(
          () => writer.write('server started',
              severity: LogLevel.info, timestamp: DateTime.now()),
        );

        expect(lines, hasLength(1));
        expect(lines.single, contains('\x1B[32m'));
        expect(lines.single, contains('[INFO'));
        expect(lines.single, contains('server started'));
        expect(lines.single, contains('\x1B[0m'));
      },
    );

    test(
      'when writing an error log, '
      'then the level tag is red',
      () async {
        final lines = await capturePrints(
          () => writer.write('it broke',
              severity: LogLevel.error, timestamp: DateTime.now()),
        );

        expect(lines.single, contains('\x1B[31m'));
      },
    );

    test(
      'when writing a warning log, '
      'then the level tag is yellow',
      () async {
        final lines = await capturePrints(
          () => writer.write('careful',
              severity: LogLevel.warning, timestamp: DateTime.now()),
        );

        expect(lines.single, contains('\x1B[33m'));
      },
    );

    test(
      'when verbose and labels/payload are provided, '
      'then they are pretty-printed on additional lines',
      () async {
        final lines = await capturePrints(
          () => writer.write(
            'request handled',
            severity: LogLevel.info,
            timestamp: DateTime.now(),
            labels: {'traceId': 'abc-123'},
            payload: {'durationMs': 12},
          ),
        );

        final output = lines.single;
        expect(output, contains('Labels:'));
        expect(output, contains('traceId'));
        expect(output, contains('Payload:'));
        expect(output, contains('durationMs'));
      },
    );

    test(
      'when verbose is false, '
      'then labels and payload are not printed',
      () async {
        const quietWriter = ConsoleLogWriter(verbose: false);
        final lines = await capturePrints(
          () => quietWriter.write(
            'request handled',
            severity: LogLevel.info,
            timestamp: DateTime.now(),
            labels: {'traceId': 'abc-123'},
            payload: {'durationMs': 12},
          ),
        );

        final output = lines.single;
        expect(output, isNot(contains('Labels:')));
        expect(output, isNot(contains('Payload:')));
      },
    );

    test(
      'when an exception and stack trace are provided, '
      'then both are printed',
      () async {
        final lines = await capturePrints(
          () => writer.write(
            'it broke',
            severity: LogLevel.error,
            timestamp: DateTime.now(),
            exception: StateError('bad'),
            stackTrace: StackTrace.current,
          ),
        );

        final output = lines.single;
        expect(output, contains('Exception:'));
        expect(output, contains('bad'));
      },
    );
  });
}
