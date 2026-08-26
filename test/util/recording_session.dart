import 'dart:async';

import 'package:serverpod/serverpod.dart';

class RecordedLog {
  RecordedLog({
    required this.message,
    this.level,
    this.exception,
    this.stackTrace,
  });

  final String message;
  final LogLevel? level;
  final Object? exception;
  final StackTrace? stackTrace;
}

/// A [Session] test double that records what reaches `session.log`.
///
/// Declaring a concrete [noSuchMethod] lets this class `implements Session`
/// without hand-writing Serverpod's whole ~30-member interface. Unimplemented
/// members forward to `super.noSuchMethod`, which **throws**, so a newly
/// touched member fails loudly here instead of returning null.
class RecordingSession implements Session {
  RecordingSession({
    String runMode = ServerpodRunMode.development,
    this.endpoint = 'test',
    this.method,
    Duration duration = const Duration(milliseconds: 5),
  })  : server = FakeServer(runMode),
        _duration = duration;

  final List<RecordedLog> logs = [];

  final List<WillCloseListener> willCloseListeners = [];

  @override
  final Server server;

  @override
  final String endpoint;

  @override
  final String? method;

  final Duration _duration;

  @override
  Duration get duration => _duration;

  @override
  final UuidValue sessionId =
      UuidValue.fromString('00000000-0000-4000-8000-000000000001');

  List<String> get loggedMessages => [for (final log in logs) log.message];

  /// The single logged message, asserting exactly one call was recorded.
  String get singleLoggedMessage {
    if (logs.length != 1) {
      throw StateError('Expected exactly 1 logged message, got ${logs.length}');
    }
    return logs.single.message;
  }

  // `metadata` does not exist on Session.log in serverpod 3.4, but does on
  // their main branch. An override may add extra optional named parameters and
  // stay a valid subtype, so declaring it now survives a `pub upgrade`.
  @override
  void log(
    String message, {
    LogLevel? level,
    dynamic exception,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
  }) {
    logs.add(RecordedLog(
      message: message,
      level: level,
      exception: exception,
      stackTrace: stackTrace,
    ));
  }

  @override
  void addWillCloseListener(WillCloseListener listener) {
    willCloseListeners.add(listener);
  }

  /// Mirrors what Serverpod does when the session closes.
  Future<void> triggerClose() async {
    for (final listener in willCloseListeners) {
      await listener(this);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Exposes only `runMode`, which is all `session.logger` reads.
class FakeServer implements Server {
  FakeServer(this.runMode);

  @override
  final String runMode;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
