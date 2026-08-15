import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/src/json_safe.dart';
import 'package:test/test.dart';

void main() {
  group('Given toJsonSafe', () {
    test(
      'when given primitive values, '
      'then they pass through unchanged',
      () {
        expect(toJsonSafe(null), isNull);
        expect(toJsonSafe('text'), 'text');
        expect(toJsonSafe(42), 42);
        expect(toJsonSafe(true), isTrue);
      },
    );

    test(
      'when given a DateTime, '
      'then it is converted to an ISO8601 string',
      () {
        final date = DateTime.utc(2026, 1, 2, 3, 4, 5);
        expect(toJsonSafe(date), date.toIso8601String());
      },
    );

    test(
      'when given a UuidValue, '
      'then it is converted to its string representation',
      () {
        final uuid =
            UuidValue.fromString('550e8400-e29b-41d4-a716-446655440000');
        expect(toJsonSafe(uuid), '550e8400-e29b-41d4-a716-446655440000');
      },
    );

    test(
      'when given a nested map containing a UuidValue and DateTime, '
      'then every value is recursively normalized',
      () {
        final input = {
          'id': UuidValue.fromString('550e8400-e29b-41d4-a716-446655440000'),
          'nested': {'createdAt': DateTime.utc(2026, 1, 1)},
        };

        final result = toJsonSafe(input) as Map<String, dynamic>;
        expect(result['id'], '550e8400-e29b-41d4-a716-446655440000');
        expect((result['nested'] as Map<String, dynamic>)['createdAt'],
            '2026-01-01T00:00:00.000Z');
      },
    );

    test(
      'when given a list of values, '
      'then each element is normalized',
      () {
        final result =
            toJsonSafe([DateTime.utc(2026), 1, 'two']) as List<dynamic>;
        expect(result, ['2026-01-01T00:00:00.000Z', 1, 'two']);
      },
    );

    test(
      'when given an enum value, '
      'then its name is used',
      () {
        expect(toJsonSafe(LogLevel.warning), 'warning');
      },
    );

    test(
      'when given an object with no toJson and no special handling, '
      'then it falls back to toString',
      () {
        final result = toJsonSafe(_Unserializable());
        expect(result, 'unserializable');
      },
    );
  });
}

class _Unserializable {
  @override
  String toString() => 'unserializable';
}
