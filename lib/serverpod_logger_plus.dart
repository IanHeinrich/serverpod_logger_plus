/// Plug-and-play structured logging for Serverpod.
///
/// Routes a flattened log message to Serverpod's session log (so it is
/// persisted to the database and visible in Serverpod Insights) while
/// emitting fully structured JSON to stdout for GCP, AWS CloudWatch,
/// Datadog, or Axiom - or a beautiful ANSI console during local development.
///
/// Typical usage:
///
/// ```dart
/// void run(List<String> args) async {
///   ServerpodLoggerPlus.configure(
///     productionWriter: const GcpJsonLogWriter(),
///   );
///
///   final pod = Serverpod(args, Protocol(), Endpoints());
///   await pod.start();
/// }
///
/// class MyEndpoint extends Endpoint {
///   Future<String> hello(Session session, String name) async {
///     await session.logger.info('Saying hello', payload: {'name': name});
///     return 'Hello, $name!';
///   }
/// }
/// ```
library;

export 'src/config.dart';
export 'src/log_writer.dart';
export 'src/logger.dart';
export 'src/session_logger_extension.dart';
export 'src/writers/axiom_log_writer.dart';
export 'src/writers/cloudwatch_json_log_writer.dart';
export 'src/writers/console_log_writer.dart';
export 'src/writers/datadog_json_log_writer.dart';
export 'src/writers/gcp_json_log_writer.dart';
