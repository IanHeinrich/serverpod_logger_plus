import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/writer_test_helpers.dart';

/// A minimal [LogWriter] that records the calls it received, for asserting
/// that [MultiLogWriter] fans out to every writer.
class _RecordingLogWriter implements LogWriter {
  final List<String> messages = [];

  @override
  Future<void> write(
    String message, {
    required LogLevel severity,
    required DateTime timestamp,
    Map<String, dynamic>? payload,
    Map<String, String>? labels,
    Object? exception,
    StackTrace? stackTrace,
  }) async {
    messages.add(message);
  }
}

void main() {
  group('Given a MultiLogWriter', () {
    test(
      'when writing, then every wrapped writer receives the same call',
      () async {
        final first = _RecordingLogWriter();
        final second = _RecordingLogWriter();
        final writer = MultiLogWriter([first, second]);

        await writer.write(
          'fanned out',
          severity: LogLevel.info,
          timestamp: DateTime.now(),
        );

        expect(first.messages, ['fanned out']);
        expect(second.messages, ['fanned out']);
      },
    );

    test(
      'when wrapping a built-in JSON writer alongside a custom writer, '
      'then the default JSON is still printed and the custom writer runs too',
      () async {
        final custom = _RecordingLogWriter();
        final writer = MultiLogWriter([const GenericJsonLogWriter(), custom]);

        final json = await writeJson(
          writer,
          message: 'checkout completed',
          severity: LogLevel.info,
          payload: {'orderId': 'o-1'},
        );

        expect(json['message'], 'checkout completed');
        expect(json['payload'], {'orderId': 'o-1'});
        expect(custom.messages, ['checkout completed']);
      },
    );

    test(
      'when one writer throws, then the others still receive the call',
      () async {
        final ok = _RecordingLogWriter();
        final writer = MultiLogWriter([const _ThrowingLogWriter(), ok]);

        await expectLater(
          writer.write(
            'still delivered',
            severity: LogLevel.error,
            timestamp: DateTime.now(),
          ),
          throwsA(isA<StateError>()),
        );

        expect(ok.messages, ['still delivered']);
      },
    );
  });
}

/// A [LogWriter] that always throws, to prove one bad writer doesn't stop the
/// rest of a [MultiLogWriter] from being dispatched.
class _ThrowingLogWriter implements LogWriter {
  const _ThrowingLogWriter();

  @override
  Future<void> write(
    String message, {
    required LogLevel severity,
    required DateTime timestamp,
    Map<String, dynamic>? payload,
    Map<String, String>? labels,
    Object? exception,
    StackTrace? stackTrace,
  }) async {
    throw StateError('boom');
  }
}
