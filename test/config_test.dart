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

    test('builds a redaction policy from the redaction options', () {
      Object? redactor(String key, Object? value) => value;

      ServerpodLoggerPlus.configure(
        productionWriter: const GenericJsonLogWriter(),
        redactKeys: {'PassWord', 'Token'},
        redactor: redactor,
        redactionPlaceholder: '***',
      );

      final policy = ServerpodLoggerPlus.redactionPolicy;
      expect(policy.isNoop, isFalse);
      expect(policy.keys, {'password', 'token'},
          reason: 'keys are lower-cased once, at configure time');
      expect(policy.redactor, same(redactor));
      expect(policy.placeholder, '***');
    });

    test('defaults to a no-op redaction policy and the default value cap', () {
      ServerpodLoggerPlus.configure(
        productionWriter: const GenericJsonLogWriter(),
      );

      expect(ServerpodLoggerPlus.redactionPolicy.isNoop, isTrue);
      expect(ServerpodLoggerPlus.flattenValueMaxLength, 1024);
    });

    test('reset clears the redaction policy and the value cap', () {
      ServerpodLoggerPlus.configure(
        productionWriter: const GenericJsonLogWriter(),
        redactKeys: {'password'},
        flattenValueMaxLength: 10,
      );

      ServerpodLoggerPlus.reset();

      expect(ServerpodLoggerPlus.redactionPolicy.isNoop, isTrue);
      expect(ServerpodLoggerPlus.flattenValueMaxLength, 1024);
    });
  });
}
