import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

/// Builds a header lookup over a simple single-value map for the parser.
String? Function(String) _lookup(Map<String, String> headers) =>
    (name) => headers[name];

void main() {
  group('traceContextFromHeaders', () {
    test('parses W3C traceparent into traceId and spanId', () {
      final trace = traceContextFromHeaders(_lookup({
        'traceparent':
            '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
      }));

      expect(trace, {
        'traceId': '4bf92f3577b34da6a3ce929d0e0e4736',
        'spanId': '00f067aa0ba902b7',
      });
    });

    test('parses GCP X-Cloud-Trace-Context with span and options', () {
      final trace = traceContextFromHeaders(_lookup({
        'x-cloud-trace-context': '105445aa7843bc8bf206b12000100000/1;o=1',
      }));

      expect(trace, {
        'traceId': '105445aa7843bc8bf206b12000100000',
        'spanId': '1',
      });
    });

    test('parses GCP header with only a trace id', () {
      final trace = traceContextFromHeaders(_lookup({
        'x-cloud-trace-context': '105445aa7843bc8bf206b12000100000',
      }));

      expect(trace, {'traceId': '105445aa7843bc8bf206b12000100000'});
    });

    test('parses AWS X-Amzn-Trace-Id Root and Parent', () {
      final trace = traceContextFromHeaders(_lookup({
        'x-amzn-trace-id':
            'Root=1-5759e988-bd862e3fe1be46a994272793;Parent=53995c3f42cd8ad8;Sampled=1',
      }));

      expect(trace, {
        'traceId': '1-5759e988-bd862e3fe1be46a994272793',
        'spanId': '53995c3f42cd8ad8',
      });
    });

    test('parses Datadog trace and parent id headers', () {
      final trace = traceContextFromHeaders(_lookup({
        'x-datadog-trace-id': '7532910810109348871',
        'x-datadog-parent-id': '1029384756',
      }));

      expect(trace, {
        'traceId': '7532910810109348871',
        'spanId': '1029384756',
      });
    });

    test('prefers W3C over other formats when several are present', () {
      final trace = traceContextFromHeaders(_lookup({
        'traceparent':
            '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
        'x-cloud-trace-context': '105445aa7843bc8bf206b12000100000/1;o=1',
        'x-datadog-trace-id': '7532910810109348871',
      }));

      expect(trace['traceId'], '4bf92f3577b34da6a3ce929d0e0e4736');
    });

    test('returns empty when no recognized header is present', () {
      expect(traceContextFromHeaders(_lookup({'user-agent': 'x'})), isEmpty);
    });

    test('ignores a malformed traceparent', () {
      expect(
        traceContextFromHeaders(_lookup({'traceparent': 'garbage'})),
        isEmpty,
      );
    });

    test('ignores a traceparent with an all-zero trace id', () {
      expect(
        traceContextFromHeaders(_lookup({
          'traceparent':
              '00-00000000000000000000000000000000-00f067aa0ba902b7-01',
        })),
        isEmpty,
      );
    });

    test('ignores a traceparent with an all-zero span id', () {
      expect(
        traceContextFromHeaders(_lookup({
          'traceparent':
              '00-4bf92f3577b34da6a3ce929d0e0e4736-0000000000000000-01',
        })),
        isEmpty,
      );
    });

    test('falls back past an all-zero traceparent to the next format', () {
      final trace = traceContextFromHeaders(_lookup({
        'traceparent':
            '00-00000000000000000000000000000000-0000000000000000-00',
        'x-datadog-trace-id': '7532910810109348871',
      }));

      expect(trace['traceId'], '7532910810109348871');
    });
  });
}
