/// Plug-and-play structured logging for Serverpod.
///
/// Routes a flattened log message to Serverpod's session log (so it is
/// persisted to the database and visible in Serverpod Insights) while
/// emitting fully structured JSON to stdout for GCP, Datadog, Elastic (ECS),
/// New Relic, Splunk, OpenTelemetry, or any generic JSON collector (AWS
/// CloudWatch, Azure Monitor, etc.) - or a beautiful ANSI console during
/// local development.
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
export 'src/trace_context.dart';
export 'src/writers/axiom_log_writer.dart';
export 'src/writers/console_log_writer.dart';
export 'src/writers/datadog_json_log_writer.dart';
export 'src/writers/elastic_ecs_log_writer.dart';
export 'src/writers/gcp_json_log_writer.dart';
export 'src/writers/generic_json_log_writer.dart';
export 'src/writers/multi_log_writer.dart';
export 'src/writers/newrelic_json_log_writer.dart';
export 'src/writers/otel_json_log_writer.dart';
export 'src/writers/splunk_json_log_writer.dart';
