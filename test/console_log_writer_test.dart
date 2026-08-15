import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/writer_test_helpers.dart';

void main() {
  group('Given a ConsoleLogWriter', () {
    const writer = ConsoleLogWriter();

    test(
      'when writing an info log, '
      'then the line contains a green level tag and resets color',
      () async {
        final line = await writeLine(writer,
            message: 'server started', severity: LogLevel.info);

        expect(line, contains('\x1B[32m'));
        expect(line, contains('[INFO'));
        expect(line, contains('server started'));
        expect(line, contains('\x1B[0m'));
      },
    );

    test(
      'when writing an error log, '
      'then the level tag is red',
      () async {
        final line = await writeLine(writer,
            message: 'it broke', severity: LogLevel.error);

        expect(line, contains('\x1B[31m'));
      },
    );

    test(
      'when writing a warning log, '
      'then the level tag is yellow',
      () async {
        final line = await writeLine(writer,
            message: 'careful', severity: LogLevel.warning);

        expect(line, contains('\x1B[33m'));
      },
    );

    test(
      'when verbose and labels/payload are provided, '
      'then they are pretty-printed on additional lines',
      () async {
        final line = await writeLine(
          writer,
          message: 'request handled',
          severity: LogLevel.info,
          labels: {'traceId': 'abc-123'},
          payload: {'durationMs': 12},
        );

        expect(line, contains('Labels:'));
        expect(line, contains('traceId'));
        expect(line, contains('Payload:'));
        expect(line, contains('durationMs'));
      },
    );

    test(
      'when verbose is false, '
      'then labels and payload are not printed',
      () async {
        const quietWriter = ConsoleLogWriter(verbose: false);
        final line = await writeLine(
          quietWriter,
          message: 'request handled',
          severity: LogLevel.info,
          labels: {'traceId': 'abc-123'},
          payload: {'durationMs': 12},
        );

        expect(line, isNot(contains('Labels:')));
        expect(line, isNot(contains('Payload:')));
      },
    );

    test(
      'when an exception and stack trace are provided, '
      'then both are printed',
      () async {
        final line = await writeLine(
          writer,
          message: 'it broke',
          severity: LogLevel.error,
          exception: StateError('bad'),
          stackTrace: StackTrace.current,
        );

        expect(line, contains('Exception:'));
        expect(line, contains('bad'));
      },
    );
  });
}
