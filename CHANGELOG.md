## 0.4.0

- New `session.bindLogger(labels:, payload:)` that enriches `session.logger` in
  place, so every later `session.logger` call on that session carries the bound
  context without threading a logger through your call stack.
- Automatic request logging: pass `logRequests: true` to
  `ServerpodLoggerPlus.configure` (or call `session.logger.logRequestOnClose()`
  per request) to emit one structured `Request completed` record (endpoint,
  method, duration) to your `LogWriter` when a session closes.
- Distributed trace context: pass `bindTraceContext: true` and `session.logger`
  reads the incoming request's trace headers and binds `traceId`/`spanId` on
  every log call. Recognizes W3C `traceparent`, GCP `X-Cloud-Trace-Context`,
  AWS `X-Amzn-Trace-Id`, and Datadog `x-datadog-trace-id`/`x-datadog-parent-id`.
  Exposes `extractTraceContext(session)` and a `traceContextExtractor` override
  for proprietary headers.
- Each writer now maps bound trace context into its provider's reserved trace
  field (OTel native `traceId`/`spanId`, ECS and New Relic `trace.id`/`span.id`,
  Datadog `dd.trace_id`/`dd.span_id`, GCP `logging.googleapis.com/trace`).
  `GcpJsonLogWriter` gains a `projectId` argument to format the reserved trace
  resource name for automatic log-to-trace linking.
- Flushing for async writers: implement the new `FlushableLogWriter` to drain
  in-flight work, and call `ServerpodLoggerPlus.flush()` from your shutdown path
  before `pod.shutdown()`. `MultiLogWriter` fans `flush()` out to flushable
  children.
- **Breaking:** `LogWriter.write` gained optional `traceId`/`spanId` named
  parameters. Custom writers that use `implements LogWriter` must add them to
  their `write` signature.

## 0.3.3

- Fix the broken CI badge in `README.md` on pub.dev (point it at the renamed
  `test.yml` workflow).

## 0.3.2

- Align repository URLs in `pubspec.yaml`, `README.md`, and `CONTRIBUTING.md`
  with the canonical `IanHeinrich` GitHub owner casing.

## 0.3.1

- Add an `example/` demonstrating every built-in writer plus the
  `session.logger` server wiring.
- Document all writer constructors.
- Shorten the pubspec `description` to pub.dev's recommended length.

## 0.3.0

- New `MultiLogWriter` that fans a single log call out to several writers, so
  you can keep a built-in structured-JSON writer *and* run extra work on top
  (e.g. an async network push) instead of having to replace the output
  entirely.

## 0.2.0

- New writers: `ElasticEcsLogWriter` (Elastic Common Schema),
  `NewRelicJsonLogWriter` (New Relic Logs), `SplunkJsonLogWriter` (Splunk),
  and `OtelJsonLogWriter` (OpenTelemetry Logs / OTLP-JSON).
- **Breaking:** replaced `CloudWatchJsonLogWriter` with the provider-neutral
  `GenericJsonLogWriter`, which emits the same flat JSON and now documents the
  full set of targets it fits (AWS CloudWatch, Azure Monitor / Container
  Insights, and any agent that indexes arbitrary stdout JSON). Swap
  `CloudWatchJsonLogWriter()` for `GenericJsonLogWriter()`.

## 0.1.0

- Initial release.
- `LoggerPlus` core Y-Splitter engine: dual-routes every log call to
  `Session.log` (Serverpod Insights) and a pluggable `LogWriter` (structured
  JSON / console output).
- Zero-boilerplate `session.logger` extension getter, memoized per session,
  auto-selecting `ConsoleLogWriter` in development and the configured
  production writer otherwise.
- Built-in writers: `GcpJsonLogWriter`, `CloudWatchJsonLogWriter`,
  `DatadogJsonLogWriter`, `AxiomLogWriter`, `ConsoleLogWriter`.
- `ServerpodLoggerPlus.configure` for global production writer configuration.
