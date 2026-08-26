import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/recording_session.dart';

/// [RecordingSession] reports `development`, so `session.logger` picks a
/// [ConsoleLogWriter] and never reaches the production-writer path, which would
/// need a fake `Serverpod` and `ServerpodConfig`.
void main() {
  tearDown(ServerpodLoggerPlus.reset);

  group('Given a session inside runWithLogger', () {
    test('when reading logger inside the scope, then scoped labels are present',
        () {
      final session = RecordingSession();

      session.runWithLogger(
        () {
          expect(session.logger.boundLabels, {'step': 'charge'});
        },
        labels: {'step': 'charge'},
      );
    });

    test('when the scope has returned, then the scoped labels are gone', () {
      final session = RecordingSession();

      session.runWithLogger(() {}, labels: {'step': 'charge'});

      expect(session.logger.boundLabels, isEmpty);
    });

    test('when the body is async, then the scope survives an await', () async {
      final session = RecordingSession();

      await session.runWithLogger(
        () async {
          await Future<void>.delayed(Duration.zero);
          expect(session.logger.boundLabels, {'step': 'charge'});
        },
        labels: {'step': 'charge'},
      );

      expect(session.logger.boundLabels, isEmpty);
    });

    test('when the body returns a value, then it is passed through', () {
      final session = RecordingSession();

      final result = session.runWithLogger(() => 42, labels: {'a': 'b'});

      expect(result, 42);
    });

    test('when scopes are nested, then the inner scope sees both label sets',
        () {
      final session = RecordingSession();

      session.runWithLogger(
        () {
          expect(session.logger.boundLabels, {'outer': '1'});
          session.runWithLogger(
            () {
              expect(session.logger.boundLabels, {'outer': '1', 'inner': '2'});
            },
            labels: {'inner': '2'},
          );
          expect(session.logger.boundLabels, {'outer': '1'},
              reason: 'inner scope unwound');
        },
        labels: {'outer': '1'},
      );
    });

    test(
      'when two Future.wait branches use different scopes, '
      'then neither sees the other labels',
      () async {
        final session = RecordingSession();
        final seen = <String, Map<String, String>>{};

        Future<void> branch(String name) => session.runWithLogger(
              () async {
                // Yield so the two branches genuinely interleave.
                await Future<void>.delayed(Duration.zero);
                seen[name] = session.logger.boundLabels;
              },
              labels: {'branch': name},
            );

        await Future.wait([branch('a'), branch('b')]);

        expect(seen['a'], {'branch': 'a'});
        expect(seen['b'], {'branch': 'b'});
        expect(session.logger.boundLabels, isEmpty);
      },
    );

    test(
        'when runWithLogger is used on one session, then another is '
        'unaffected', () {
      final first = RecordingSession();
      final second = RecordingSession();

      first.runWithLogger(
        () {
          expect(first.logger.boundLabels, {'scoped': 'yes'});
          expect(second.logger.boundLabels, isEmpty);
        },
        labels: {'scoped': 'yes'},
      );
    });
  });

  group('Given bindLogger', () {
    test('when called outside any scope, then it re-points session.logger', () {
      final session = RecordingSession();

      session.bindLogger(labels: {'requestId': 'abc'});

      expect(session.logger.boundLabels, {'requestId': 'abc'});
    });

    test('when called inside a scope, then later calls in the scope see it',
        () {
      final session = RecordingSession();

      session.runWithLogger(
        () {
          session.bindLogger(labels: {'added': 'inside'});
          expect(
            session.logger.boundLabels,
            {'step': 'charge', 'added': 'inside'},
          );
        },
        labels: {'step': 'charge'},
      );
    });

    test('when called inside a scope, then calls after the scope do not see it',
        () {
      final session = RecordingSession();

      session.runWithLogger(
        () => session.bindLogger(labels: {'added': 'inside'}),
        labels: {'step': 'charge'},
      );

      expect(session.logger.boundLabels, isEmpty,
          reason: 'a bind inside a scope must not leak past it');
    });
  });
}
