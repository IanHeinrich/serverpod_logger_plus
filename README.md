# serverpod_logger_plus

[![pub package](https://img.shields.io/pub/v/serverpod_logger_plus.svg)](https://pub.dev/packages/serverpod_logger_plus)
[![CI](https://github.com/ianheinrich/serverpod_logger_plus/actions/workflows/ci.yml/badge.svg)](https://github.com/ianheinrich/serverpod_logger_plus/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Plug-and-play structured logging for [Serverpod](https://serverpod.dev).

Every log call is dual-routed (the **"Y-Splitter"**):

- A flattened, human-readable string is sent to `Session.log`, so it's still
  persisted to the Serverpod database and shows up in **Serverpod Insights**,
  exactly like `session.log(...)` today.
- The fully structured data (message, labels, payload, exception, stack
  trace) is sent to a pluggable `LogWriter`, which prints it as JSON on
  `stdout` for your log aggregator - or as colorized output for local
  development.

You still get Insights, plus structured logs your cloud provider can
actually query, filter, and alert on.

## Install

```yaml
dependencies:
  serverpod_logger_plus: ^0.1.0
```

## Quickstart

```dart
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';

void run(List<String> args) async {
  // Pick the writer for your production log sink. Required once, at
  // startup, before any request accesses `session.logger`.
  ServerpodLoggerPlus.configure(
    productionWriter: const GcpJsonLogWriter(),
  );

  final pod = Serverpod(args, Protocol(), Endpoints());
  await pod.start();
}
```

Then, anywhere you have a `Session`:

```dart
class GreetingEndpoint extends Endpoint {
  Future<String> hello(Session session, String name) async {
    await session.logger.info('Saying hello', payload: {'name': name});
    return 'Hello, $name!';
  }
}
```

No manual wiring per-endpoint: `session.logger` is a zero-boilerplate
extension getter, lazily created and memoized per `Session`. It automatically
picks the right writer:

- `runMode == development` → a local ANSI `ConsoleLogWriter`, regardless of
  what you passed to `configure`.
- Any other run mode (`staging`, `production`, `test`, ...) → the
  `productionWriter` registered via `ServerpodLoggerPlus.configure`.

### Suppressing low-severity noise

By default every level is written. Pass `minimumLevel` to drop calls below a
threshold from the writer's output - useful for keeping `debug` chatter (and
its ingestion cost) out of production log sinks:

```dart
ServerpodLoggerPlus.configure(
  productionWriter: const GcpJsonLogWriter(),
  minimumLevel: LogLevel.info, // debug is dropped by the writer
);
```

This gates only this package's writer. Serverpod's own session log is
unaffected and continues to be filtered by Serverpod's log settings, so
dropped-from-stdout entries can still reach the database/Insights.

### Avoiding double logging in production

Separately from this package, Serverpod's own `Session.log` can *also*
write a JSON or text line straight to stdout, controlled by
`sessionLogs.consoleEnabled` in your server config
(`config/<env>.yaml`). Its default value is
`!databaseEnabled || runMode == development` - i.e. **off** by default in
`staging`/`production` as long as a database is configured, but **on** by
default for database-less setups (like Serverpod Mini), or if you've
explicitly set `sessionLogs: { consoleEnabled: true }` for that environment.

If it's on in the same run mode where you've configured a `productionWriter`,
every log call is printed to stdout twice - once by Serverpod's own writer,
once by yours. `session.logger` detects this and prints a one-time warning
to stderr when it happens. To avoid the duplication, set
`sessionLogs: { consoleEnabled: false }` in that environment's config (or
the `SERVERPOD_SESSION_CONSOLE_LOG_ENABLED` env var), unless you actually
want both.

## API

### Logging methods

`LoggerPlus` (the object returned by `session.logger`) exposes:

```dart
session.logger.debug('message', payload: {...}, labels: {...});
session.logger.info('message', payload: {...}, labels: {...});
session.logger.warning('message', payload: {...}, labels: {...});
session.logger.error('message', exception: e, stackTrace: st, payload: {...});
session.logger.fatal('message', exception: e, stackTrace: st, payload: {...});
```

- `payload` - arbitrary structured data relevant to this one log call (e.g.
  `{'userId': id}`).
- `labels` - key/value tags meant to be consistent across many log calls
  (e.g. `{'requestId': id}`), suitable for indexing/filtering in your log
  backend.

### Binding context

Use `bind` to attach labels/payload that should be included on every
subsequent call made through the returned logger, without repeating them:

```dart
final requestLogger = session.logger.bind(
  labels: {'requestId': requestId},
);

await requestLogger.info('Starting request');
await requestLogger.info('Finished request'); // still tagged with requestId
```

`bind` returns a new `LoggerPlus`; the original is left unchanged.

> Note: the class is named `LoggerPlus`, not `Logger` - `package:serverpod`
> already exports its own `Logger` (from `relic_core`, used internally for
> HTTP request logging), so naming ours `Logger` would collide with it in
> every file that imports both packages.

## Writers

Pick one `LogWriter` as your `productionWriter`. Each one emits a single
line of JSON per log call, shaped for its target platform's structured
logging / reserved-attribute conventions:

| Writer | Target | Notes |
| --- | --- | --- |
| `GcpJsonLogWriter` | Google Cloud Logging | Emits `severity` (`DEBUG`/`INFO`/`WARNING`/`ERROR`/`CRITICAL`) and `logging.googleapis.com/labels`, auto-parsed from stdout by the Cloud Logging agent. |
| `CloudWatchJsonLogWriter` | AWS CloudWatch Logs | Emits `level`, `timestamp`, `labels`, `payload`. |
| `DatadogJsonLogWriter` | Datadog Log Management | Emits `status` (Datadog's reserved severity attribute - *not* `level`), `@timestamp`, `error.message`/`error.kind`/`error.stack` on exceptions. |
| `AxiomLogWriter` | Axiom / generic JSON collectors (e.g. Better Stack) | Emits `_time`, `level`, and a merged `data` object combining `payload` and `labels`. |
| `ConsoleLogWriter` | Local development | ANSI-colored, human-readable console output. Automatically used whenever `runMode == development`. |

All writers only ever call `print(...)` (never `stdout.writeln`), so they
play nicely with Zone-based print interception in tests.

### Writing your own writer

Implement `LogWriter` to support any other destination. `write` is
dispatched without being awaited by the caller, so it's safe to perform
slower work (e.g. a network call) here without adding latency to the
request - just make sure it never throws:

```dart
class MyLogWriter implements LogWriter {
  const MyLogWriter();

  @override
  Future<void> write(
    String message, {
    required LogLevel severity,
    required DateTime timestamp,
    Map<String, dynamic>? payload,
    Map<String, String>? labels,
    Object? exception,
    StackTrace? stackTrace,
  }) async {
    // ship `message`/`payload`/`labels`/`exception` wherever you like.
  }
}
```

## Testing

`serverpod_logger_plus` itself is covered by writer-schema unit tests (see
`test/`) run with plain `package:test`, using a `Zone`-based `print`
interceptor (`test/util/capture_print.dart`) to assert on each writer's JSON
output without touching real stdout.

To verify the Y-Splitter behavior end-to-end *inside your own Serverpod
server*, write an integration test with
[`serverpod_test`](https://pub.dev/packages/serverpod_test)'s
`withServerpod`, and assert both routes are exercised - `session.log`
doesn't throw, and your writer received the structured data:

```dart
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
import 'package:serverpod_test/serverpod_test.dart';

import '../lib/src/generated/protocol.dart';
import '../lib/src/generated/endpoints.dart';

class RecordingLogWriter implements LogWriter {
  final calls = <String>[];

  @override
  Future<void> write(
    String message, {
    required LogLevel severity,
    required DateTime timestamp,
    Map<String, dynamic>? payload,
    Map<String, String>? labels,
    Object? exception,
    StackTrace? stackTrace,
  }) async {
    calls.add(message);
  }
}

void main() {
  withServerpod('Given a configured LoggerPlus', (sessionBuilder, endpoints) {
    test('when info is logged, then session.log does not throw '
        'and the writer receives the structured data', () async {
      final writer = RecordingLogWriter();
      final session = sessionBuilder.build();
      final logger = LoggerPlus(session, writer: writer);

      await logger.info('Hello from a test');

      expect(writer.calls, contains('Hello from a test'));
    });
  });
}
```

This test needs to live inside a real generated Serverpod project (it
imports that project's generated `protocol.dart`/`endpoints.dart`), so it
isn't bundled in this package - copy the pattern above into your server's
`test/integration/` directory.

## License

MIT