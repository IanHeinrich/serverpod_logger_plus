import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:test/test.dart';

import 'util/recording_log_writer.dart';
import 'util/recording_session.dart';

/// `_dispatchToWriter` fires the writer with `unawaited`, so yield once before
/// asserting on the writer side.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('Given a LoggerPlus', () {
    test(
      'when logging with labels and payload, '
      'then the session log receives the flattened string',
      () async {
        final session = RecordingSession();
        final writer = RecordingLogWriter();
        final logger = LoggerPlus(session, writer: writer);

        await logger.info(
          'user signed in',
          labels: {'requestId': 'abc'},
          payload: {'userId': 7},
        );
        await settle();

        expect(
          session.singleLoggedMessage,
          'user signed in | labels: requestId=abc | payload: userId=7',
        );
        expect(session.logs.single.level, LogLevel.info);
      },
    );

    test(
      'when logging, then both sinks receive the call',
      () async {
        final session = RecordingSession();
        final writer = RecordingLogWriter();
        final logger = LoggerPlus(session, writer: writer);

        await logger.warning('careful', payload: {'k': 'v'});
        await settle();

        expect(session.logs, hasLength(1));
        expect(writer.calls, hasLength(1));
        expect(writer.single.message, 'careful');
        expect(writer.single.severity, LogLevel.warning);
        expect(writer.single.payload, {'k': 'v'});
      },
    );

    test(
      'when a message has no labels or payload, '
      'then the session log receives the bare message',
      () async {
        final session = RecordingSession();
        final logger = LoggerPlus(session, writer: RecordingLogWriter());

        await logger.debug('plain');
        await settle();

        expect(session.singleLoggedMessage, 'plain');
      },
    );

    test(
      'when call-site labels collide with bound labels, '
      'then the call-site value wins',
      () async {
        final session = RecordingSession();
        final writer = RecordingLogWriter();
        final logger = LoggerPlus(session, writer: writer)
            .bind(labels: {'scope': 'bound', 'kept': 'yes'});

        await logger.info('merged', labels: {'scope': 'call'});
        await settle();

        expect(writer.single.labels, {'scope': 'call', 'kept': 'yes'});
      },
    );
  });

  group('Given a LoggerPlus with a minimumLevel', () {
    test(
      'when a call is below the minimum, '
      'then the writer is not called but the session log still is',
      () async {
        final session = RecordingSession();
        final writer = RecordingLogWriter();
        final logger = LoggerPlus(
          session,
          writer: writer,
          minimumLevel: LogLevel.error,
        );

        await logger.info('below the bar', payload: {'userId': 7});
        await settle();

        expect(writer.calls, isEmpty);
        expect(session.logs, hasLength(1));
        expect(session.singleLoggedMessage, contains('userId=7'));
      },
    );

    test(
      'when a call is at or above the minimum, then both sinks receive it',
      () async {
        final session = RecordingSession();
        final writer = RecordingLogWriter();
        final logger = LoggerPlus(
          session,
          writer: writer,
          minimumLevel: LogLevel.error,
        );

        await logger.error('at the bar');
        await logger.fatal('above the bar');
        await settle();

        expect(writer.calls, hasLength(2));
        expect(session.logs, hasLength(2));
      },
    );
  });

  group('Given a LoggerPlus with a redaction policy', () {
    test(
      'when a payload key is redacted, '
      'then the secret reaches neither the writer nor the session log',
      () async {
        final session = RecordingSession();
        final writer = RecordingLogWriter();
        final logger = LoggerPlus(
          session,
          writer: writer,
          redaction: RedactionPolicy(keys: {'PassWord'}),
        );

        await logger.info(
          'login',
          payload: {'user': 'ada', 'password': 'hunter2'},
        );
        await settle();

        expect(writer.single.payload!['password'], '[redacted]');
        expect(jsonEncode(writer.single.payload), isNot(contains('hunter2')));
        expect(session.singleLoggedMessage, contains('password=[redacted]'));
        expect(session.singleLoggedMessage, isNot(contains('hunter2')));
      },
    );

    test(
      'when a label is redacted, then the placeholder reaches both sinks',
      () async {
        final session = RecordingSession();
        final writer = RecordingLogWriter();
        final logger = LoggerPlus(
          session,
          writer: writer,
          redaction: RedactionPolicy(keys: {'apikey'}),
        );

        await logger.info('call', labels: {'apiKey': 'sk-live-123'});
        await settle();

        expect(writer.single.labels, {'apiKey': '[redacted]'});
        expect(session.singleLoggedMessage, isNot(contains('sk-live-123')));
      },
    );

    test(
      'when bound payload holds a redacted key, then every call redacts it',
      () async {
        final session = RecordingSession();
        final writer = RecordingLogWriter();
        final logger = LoggerPlus(
          session,
          writer: writer,
          redaction: RedactionPolicy(keys: {'token'}),
          payload: {'token': 'secret'},
        );

        await logger.info('first');
        await logger.info('second');
        await settle();

        for (final call in writer.calls) {
          expect(call.payload!['token'], '[redacted]');
        }
        for (final message in session.loggedMessages) {
          expect(message, isNot(contains('secret')));
        }
      },
    );

    test(
      'when the logger is re-bound with bind(), '
      'then the bound logger still redacts and still truncates',
      () async {
        final session = RecordingSession();
        final writer = RecordingLogWriter();
        final logger = LoggerPlus(
          session,
          writer: writer,
          redaction: RedactionPolicy(keys: {'token'}),
          flattenValueMaxLength: 10,
        ).bind(labels: {'scope': 'child'});

        await logger.info(
          'bound',
          payload: {'token': 'secret', 'long': 'y' * 50},
        );
        await settle();

        expect(writer.single.payload!['token'], '[redacted]');
        expect(session.singleLoggedMessage, isNot(contains('secret')));
        expect(session.singleLoggedMessage, contains('...[+40 chars]'));
      },
    );

    test(
      'when the message itself holds the secret, then it is NOT redacted',
      () async {
        final session = RecordingSession();
        final writer = RecordingLogWriter();
        final logger = LoggerPlus(
          session,
          writer: writer,
          redaction: RedactionPolicy(keys: {'password'}),
        );

        await logger.info('login failed for password hunter2');
        await settle();

        expect(writer.single.message, contains('hunter2'));
        expect(session.singleLoggedMessage, contains('hunter2'));
      },
    );
  });

  group('Given a LoggerPlus with request logging registered', () {
    test(
      'when the session closes, then one request-completed record is emitted',
      () async {
        final session = RecordingSession(endpoint: 'greeting', method: 'hello');
        final writer = RecordingLogWriter();
        LoggerPlus(session, writer: writer).logRequestOnClose();

        expect(writer.calls, isEmpty, reason: 'nothing before close');

        await session.triggerClose();
        await settle();

        expect(writer.single.message, 'Request completed');
        expect(writer.single.labels, {'event': 'request_completed'});
        expect(writer.single.payload!['endpoint'], 'greeting');
        expect(writer.single.payload!['method'], 'hello');
        expect(writer.single.payload!['durationMs'], isA<int>());
      },
    );

    test(
      'when logRequestOnClose is called twice, then only one listener registers',
      () async {
        final session = RecordingSession();
        final logger = LoggerPlus(session, writer: RecordingLogWriter())
          ..logRequestOnClose()
          ..logRequestOnClose();

        expect(logger, isNotNull);
        expect(session.willCloseListeners, hasLength(1));
      },
    );
  });
}
