// A runnable tour of `serverpod_logger_plus`.
//
// This file demonstrates the two things the package gives you:
//
//   1. A set of `LogWriter`s that each emit structured JSON on the schema a
//      specific log sink expects. This part is fully self-contained and runs
//      with `dart run example/main.dart` - no Serverpod server required.
//   2. The zero-boilerplate `session.logger` wiring you add to a real
//      Serverpod server. That part needs generated Serverpod code, so it is
//      shown in the commented `runServer` function at the bottom.
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';

Future<void> main() async {
  final timestamp = DateTime.utc(2026, 1, 1, 12, 0, 0);

  // Each writer prints one JSON line to stdout on its own provider's schema.
  final writers = <String, LogWriter>{
    'GCP Cloud Logging': const GcpJsonLogWriter(),
    'Datadog': const DatadogJsonLogWriter(),
    'Elastic (ECS)': const ElasticEcsLogWriter(),
    'Generic JSON (CloudWatch, Azure, ...)': const GenericJsonLogWriter(),
    'Local ANSI console': const ConsoleLogWriter(),
  };

  for (final entry in writers.entries) {
    print('\n--- ${entry.key} ---');

    await entry.value.write(
      'User signed in',
      severity: LogLevel.info,
      timestamp: timestamp,
      labels: {'endpoint': 'auth', 'method': 'signIn'},
      payload: {'userId': 42, 'plan': 'pro'},
    );

    await entry.value.write(
      'Payment failed',
      severity: LogLevel.error,
      timestamp: timestamp,
      labels: {'endpoint': 'billing'},
      payload: {'invoiceId': 'inv_123'},
      exception: StateError('card declined'),
      stackTrace: StackTrace.current,
    );
  }

  // Send one log call to several sinks at once with MultiLogWriter.
  print('\n--- MultiLogWriter (GCP + generic) ---');
  await const MultiLogWriter([
    GcpJsonLogWriter(),
    GenericJsonLogWriter(),
  ]).write(
    'Fan-out example',
    severity: LogLevel.warning,
    timestamp: timestamp,
  );
}

// ---------------------------------------------------------------------------
// In a real Serverpod server, you never call `writer.write` yourself. You
// configure the production writer once at startup, then use the
// `session.logger` extension getter anywhere you have a `Session`.
//
// This block is commented out because it depends on the `Protocol` and
// `Endpoints` classes generated in your own server project.
//
// import 'package:serverpod/serverpod.dart';
// import 'package:serverpod_logger_plus/serverpod_logger_plus.dart';
// import 'src/generated/protocol.dart';
// import 'src/generated/endpoints.dart';
//
// void run(List<String> args) async {
//   // Pick the writer for your production log sink. Required once, at
//   // startup, before any request accesses `session.logger`. In
//   // `runMode == development`, a local ANSI ConsoleLogWriter is used instead,
//   // regardless of what you pass here.
//   ServerpodLoggerPlus.configure(
//     productionWriter: const GcpJsonLogWriter(),
//     minimumLevel: LogLevel.info, // optionally drop debug noise from stdout
//   );
//
//   final pod = Serverpod(args, Protocol(), Endpoints());
//   await pod.start();
// }
//
// class GreetingEndpoint extends Endpoint {
//   Future<String> hello(Session session, String name) async {
//     await session.logger.info('Saying hello', payload: {'name': name});
//     return 'Hello, $name!';
//   }
// }
