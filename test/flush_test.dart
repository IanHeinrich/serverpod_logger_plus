import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

/// A flushable writer that counts how many times [flush] was invoked.
class _CountingFlushWriter implements FlushableLogWriter {
  int flushCount = 0;

  @override
  Future<void> write(
    String message, {
    required LogLevel severity,
    required DateTime timestamp,
    Map<String, dynamic>? payload,
    Map<String, String>? labels,
    Object? exception,
    StackTrace? stackTrace,
    String? traceId,
    String? spanId,
  }) async {}

  @override
  Future<void> flush() async => flushCount++;
}

void main() {
  tearDown(ServerpodLoggerPlus.reset);

  group('MultiLogWriter.flush', () {
    test('fans out only to flushable child writers', () async {
      final flushable = _CountingFlushWriter();

      // A plain (non-flushable) writer must simply be skipped, not fail.
      await MultiLogWriter([flushable, const GenericJsonLogWriter()]).flush();

      expect(flushable.flushCount, 1);
    });
  });

  group('ServerpodLoggerPlus.flush', () {
    test('drains a configured flushable production writer', () async {
      final writer = _CountingFlushWriter();
      ServerpodLoggerPlus.configure(productionWriter: writer);

      await ServerpodLoggerPlus.flush();

      expect(writer.flushCount, 1);
    });

    test('is a no-op for a non-flushable writer', () async {
      ServerpodLoggerPlus.configure(
        productionWriter: const GenericJsonLogWriter(),
      );

      await expectLater(ServerpodLoggerPlus.flush(), completes);
    });

    test('is a safe no-op when no writer is configured', () async {
      await expectLater(ServerpodLoggerPlus.flush(), completes);
    });
  });
}
