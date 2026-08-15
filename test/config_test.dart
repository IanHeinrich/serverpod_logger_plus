import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

void main() {
  tearDown(ServerpodLoggerPlus.reset);

  group('ServerpodLoggerPlus.configure', () {
    test('stores the trace-context extractor and other flags', () {
      Map<String, String> extractor(Session session) => const {};

      ServerpodLoggerPlus.configure(
        productionWriter: const GenericJsonLogWriter(),
        logRequests: true,
        bindTraceContext: true,
        traceContextExtractor: extractor,
      );

      expect(ServerpodLoggerPlus.logRequests, isTrue);
      expect(ServerpodLoggerPlus.bindTraceContext, isTrue);
      expect(ServerpodLoggerPlus.traceContextExtractor, same(extractor));
    });

    test('reset clears the trace-context extractor and flags', () {
      ServerpodLoggerPlus.configure(
        productionWriter: const GenericJsonLogWriter(),
        logRequests: true,
        bindTraceContext: true,
        traceContextExtractor: (session) => const {},
      );

      ServerpodLoggerPlus.reset();

      expect(ServerpodLoggerPlus.logRequests, isFalse);
      expect(ServerpodLoggerPlus.bindTraceContext, isFalse);
      expect(ServerpodLoggerPlus.traceContextExtractor, isNull);
    });
  });
}
