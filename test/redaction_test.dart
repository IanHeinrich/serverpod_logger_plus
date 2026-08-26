import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

void main() {
  group('Given a RedactionPolicy with redactKeys', () {
    final policy = RedactionPolicy(keys: {'password', 'token'});

    test('when a payload key matches exactly, then the value is replaced', () {
      expect(
        policy.applyToPayload({'user': 'ada', 'password': 'hunter2'}),
        {'user': 'ada', 'password': '[redacted]'},
      );
    });

    test('when a payload key matches in another case, then it is replaced', () {
      final result = RedactionPolicy(keys: {'PassWord'})
          .applyToPayload({'PASSWORD': 'a', 'password': 'b', 'Password': 'c'});

      expect(result, {
        'PASSWORD': '[redacted]',
        'password': '[redacted]',
        'Password': '[redacted]',
      });
    });

    test('when a nested map holds a matching key, then only that is replaced',
        () {
      expect(
        policy.applyToPayload({
          'user': {'name': 'ada', 'password': 'hunter2'}
        }),
        {
          'user': {'name': 'ada', 'password': '[redacted]'}
        },
      );
    });

    test('when a list of maps holds matching keys, then each is replaced', () {
      expect(
        policy.applyToPayload({
          'users': [
            {'name': 'ada', 'token': 't1'},
            {'name': 'bob', 'token': 't2'},
          ]
        }),
        {
          'users': [
            {'name': 'ada', 'token': '[redacted]'},
            {'name': 'bob', 'token': '[redacted]'},
          ]
        },
      );
    });

    test('when a matching key holds a map, then the whole subtree is replaced',
        () {
      expect(
        policy.applyToPayload({
          'token': {'value': 'secret', 'refresh': 'also-secret'}
        }),
        {'token': '[redacted]'},
      );
    });

    test('when no key matches, then the same instance is returned', () {
      final payload = {'user': 'ada'};

      expect(identical(policy.applyToPayload(payload), payload), isTrue);
    });

    test('when the placeholder is customised, then it is used', () {
      final custom = RedactionPolicy(keys: {'password'}, placeholder: '***')
          .applyToPayload(
        {'password': 'hunter2'},
      );

      expect(custom, {'password': '***'});
    });
  });

  group('Given a no-op RedactionPolicy', () {
    test('when applied, then the identical map instances are returned', () {
      final labels = {'a': 'b'};
      final payload = {'c': 'd'};

      expect(RedactionPolicy.none.isNoop, isTrue);
      expect(identical(RedactionPolicy.none.applyToLabels(labels), labels),
          isTrue);
      expect(identical(RedactionPolicy.none.applyToPayload(payload), payload),
          isTrue);
    });
  });

  group('Given a RedactionPolicy with a redactor', () {
    test('when a key matches redactKeys, then the redactor is not called', () {
      final seenKeys = <String>[];
      final policy = RedactionPolicy(
        keys: {'password'},
        redactor: (key, value) {
          seenKeys.add(key);
          return value;
        },
      );

      final result = policy.applyToPayload({'password': 'x', 'user': 'ada'});

      expect(result, {'password': '[redacted]', 'user': 'ada'});
      expect(seenKeys, ['user'], reason: 'redactKeys short-circuits');
    });

    test('when the redactor returns a new value, then it replaces the original',
        () {
      final policy = RedactionPolicy(
        redactor: (key, value) =>
            value is String && value.startsWith('4111') ? '[card]' : value,
      );

      expect(
        policy.applyToPayload({'pan': '4111111111111111', 'other': 'keep'}),
        {'pan': '[card]', 'other': 'keep'},
      );
    });

    test(
        'when the redactor returns a new value for a map, then it is not '
        'walked further', () {
      final policy = RedactionPolicy(
        redactor: (key, value) => key == 'user' ? 'collapsed' : value,
      );

      expect(
        policy.applyToPayload({
          'user': {'name': 'ada'}
        }),
        {'user': 'collapsed'},
      );
    });

    test('when the redactor returns its input, then nested entries are walked',
        () {
      final seenKeys = <String>[];
      final policy = RedactionPolicy(
        redactor: (key, value) {
          seenKeys.add(key);
          return value;
        },
      );

      policy.applyToPayload({
        'user': {'name': 'ada'}
      });

      expect(seenKeys, containsAll(<String>['user', 'name']));
    });

    test(
        'when the redactor returns null for a payload entry, then the entry '
        'is kept as null', () {
      final policy = RedactionPolicy(
        redactor: (key, value) => key == 'drop' ? null : value,
      );

      final result = policy.applyToPayload({'drop': 'x', 'keep': 'y'});

      expect(result.containsKey('drop'), isTrue);
      expect(result['drop'], isNull);
      expect(result['keep'], 'y');
    });

    test(
        'when the redactor returns null for a label, then the label is '
        'dropped', () {
      final policy = RedactionPolicy(
        redactor: (key, value) => key == 'drop' ? null : value,
      );

      final result = policy.applyToLabels({'drop': 'x', 'keep': 'y'});

      expect(result.containsKey('drop'), isFalse);
      expect(result, {'keep': 'y'});
    });

    test(
        'when the redactor returns a non-String for a label, then it is '
        'stringified', () {
      final policy = RedactionPolicy(
        redactor: (key, value) => key == 'count' ? 42 : value,
      );

      expect(policy.applyToLabels({'count': 'x'}), {'count': '42'});
    });

    test(
        'when the redactor throws, then the value is replaced and nothing is '
        'rethrown', () {
      final policy = RedactionPolicy(
        redactor: (key, value) => throw StateError('boom'),
      );

      expect(
        () => policy.applyToPayload({'k': 'v'}),
        returnsNormally,
      );
      expect(policy.applyToPayload({'k': 'v'}), {'k': '[redacted]'});
    });
  });

  group('Given a RedactionPolicy and a deeply nested payload', () {
    final policy = RedactionPolicy(keys: {'password'});

    test('when nesting exceeds maxDepth, then a marker is substituted', () {
      dynamic nested = 'leaf';
      for (var i = 0; i < RedactionPolicy.maxDepth + 4; i++) {
        nested = {'down': nested};
      }

      expect(
        policy.applyToPayload({'root': nested}).toString(),
        contains(redactionMaxDepthMarker),
      );
    });

    test('when the payload contains a cycle, then redaction terminates', () {
      final cyclic = <String, dynamic>{'name': 'root'};
      cyclic['self'] = cyclic;

      expect(() => policy.applyToPayload(cyclic), returnsNormally);
    });

    test('when a matching key sits below a list of lists, then it is replaced',
        () {
      expect(
        policy.applyToPayload({
          'rows': [
            [
              {'password': 'x'}
            ]
          ]
        }),
        {
          'rows': [
            [
              {'password': '[redacted]'}
            ]
          ]
        },
      );
    });
  });
}
