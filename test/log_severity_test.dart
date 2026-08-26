import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/writer_test_helpers.dart';

void main() {
  group('logSeverityRank', () {
    test('ranks ascend from debug to fatal', () {
      expect(
        [
          LogLevel.debug,
          LogLevel.info,
          LogLevel.warning,
          LogLevel.error,
          LogLevel.fatal,
        ].map(logSeverityRank),
        [0, 1, 2, 3, 4],
      );
    });

    test('assigns every LogLevel a distinct rank', () {
      final ranks = LogLevel.values.map(logSeverityRank).toSet();
      expect(ranks, hasLength(LogLevel.values.length));
    });

    test('orders levels the same way the OTel writer does', () async {
      // OtelJsonLogWriter keeps its own LogLevel -> severityNumber table,
      // private, so read it back through the public writer.
      final severityNumbers = <LogLevel, int>{};
      for (final level in LogLevel.values) {
        final record = await writeJson(
          const OtelJsonLogWriter(),
          severity: level,
        );
        severityNumbers[level] = record['severityNumber'] as int;
      }

      final byRank = LogLevel.values.toList()
        ..sort((a, b) => logSeverityRank(a).compareTo(logSeverityRank(b)));
      final byOtel = LogLevel.values.toList()
        ..sort((a, b) => severityNumbers[a]!.compareTo(severityNumbers[b]!));

      expect(byRank, byOtel);
    });
  });
}
