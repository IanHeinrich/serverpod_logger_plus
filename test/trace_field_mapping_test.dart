import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/writer_test_helpers.dart';

void main() {
  const traceId = '4bf92f3577b34da6a3ce929d0e0e4736';
  const spanId = '00f067aa0ba902b7';

  group('OtelJsonLogWriter', () {
    test('maps trace context to the native LogRecord fields', () async {
      final json = await writeJson(
        const OtelJsonLogWriter(),
        severity: LogLevel.info,
        traceId: traceId,
        spanId: spanId,
      );

      expect(json['traceId'], traceId);
      expect(json['spanId'], spanId);
    });
  });

  group('ElasticEcsLogWriter', () {
    test('maps trace context to ECS trace.id/span.id', () async {
      final json = await writeJson(
        const ElasticEcsLogWriter(),
        severity: LogLevel.info,
        traceId: traceId,
        spanId: spanId,
      );

      expect(json['trace.id'], traceId);
      expect(json['span.id'], spanId);
    });
  });

  group('NewRelicJsonLogWriter', () {
    test('maps trace context to trace.id/span.id', () async {
      final json = await writeJson(
        const NewRelicJsonLogWriter(),
        severity: LogLevel.info,
        traceId: traceId,
        spanId: spanId,
      );

      expect(json['trace.id'], traceId);
      expect(json['span.id'], spanId);
    });
  });

  group('DatadogJsonLogWriter', () {
    test('maps trace context to dd.trace_id/dd.span_id', () async {
      final json = await writeJson(
        const DatadogJsonLogWriter(),
        severity: LogLevel.info,
        traceId: traceId,
        spanId: spanId,
      );

      expect(json['dd.trace_id'], traceId);
      expect(json['dd.span_id'], spanId);
    });
  });

  group('GcpJsonLogWriter', () {
    test('with a project id, formats the reserved trace resource name',
        () async {
      final json = await writeJson(
        const GcpJsonLogWriter(projectId: 'my-project'),
        severity: LogLevel.info,
        traceId: traceId,
        spanId: spanId,
      );

      expect(
        json['logging.googleapis.com/trace'],
        'projects/my-project/traces/$traceId',
      );
      expect(json['logging.googleapis.com/spanId'], spanId);
    });

    test('without a project id, emits the reserved trace field in bare form',
        () async {
      final json = await writeJson(
        const GcpJsonLogWriter(),
        severity: LogLevel.info,
        traceId: traceId,
        spanId: spanId,
      );

      expect(json['logging.googleapis.com/trace'], traceId);
      expect(json['logging.googleapis.com/spanId'], spanId);
      expect(json.containsKey('logging.googleapis.com/labels'), isFalse);
    });

    test('converts a decimal span id to 16-character hex', () async {
      final json = await writeJson(
        const GcpJsonLogWriter(projectId: 'my-project'),
        severity: LogLevel.info,
        traceId: traceId,
        spanId: '1',
      );

      expect(json['logging.googleapis.com/spanId'], '0000000000000001');
    });
  });

  group('provider-neutral writers', () {
    test('GenericJsonLogWriter emits traceId/spanId', () async {
      final json = await writeJson(
        const GenericJsonLogWriter(),
        severity: LogLevel.info,
        traceId: traceId,
        spanId: spanId,
      );

      expect(json['traceId'], traceId);
      expect(json['spanId'], spanId);
    });

    test('SplunkJsonLogWriter emits trace_id/span_id', () async {
      final json = await writeJson(
        const SplunkJsonLogWriter(),
        severity: LogLevel.info,
        traceId: traceId,
        spanId: spanId,
      );

      expect(json['trace_id'], traceId);
      expect(json['span_id'], spanId);
    });

    test('AxiomLogWriter emits trace_id/span_id', () async {
      final json = await writeJson(
        const AxiomLogWriter(),
        severity: LogLevel.info,
        traceId: traceId,
        spanId: spanId,
      );

      expect(json['trace_id'], traceId);
      expect(json['span_id'], spanId);
    });
  });

  group('ConsoleLogWriter', () {
    test('includes trace context in the human-readable line', () async {
      final line = await writeLine(
        const ConsoleLogWriter(),
        severity: LogLevel.info,
        traceId: traceId,
        spanId: spanId,
      );

      expect(line, contains('trace=$traceId'));
      expect(line, contains('span=$spanId'));
    });
  });

  group('when no trace context is bound', () {
    test('writers omit the trace fields', () async {
      final json = await writeJson(
        const GenericJsonLogWriter(),
        severity: LogLevel.info,
      );

      expect(json.containsKey('traceId'), isFalse);
      expect(json.containsKey('spanId'), isFalse);
    });
  });
}
