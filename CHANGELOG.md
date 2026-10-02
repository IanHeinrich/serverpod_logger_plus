## 0.5.2

- The configured `redactor` now also runs over a logged exception's text. It is
  called with the key `'exception'` (exported as `exceptionRedactionKey`) and
  `exception.toString()`, so a Postgres error such as
  `Key (email)=(x@y.com) already exists` can be scrubbed before it reaches
  Serverpod's session-log table or your `LogWriter`. When the redactor changes
  the text, both sinks receive a `RedactedException` whose `toString()` is the
  new text and whose `runtimeType` is the original exception's type. Returning
  `null` drops the exception. Without a `redactor` the exception is passed
  through untouched and is not stringified. `redactKeys` does not apply to
  exception text, and stack traces are not scanned.

## 0.5.1

- Supports Serverpod 4.0.x as well as 3.4.x: the `serverpod` constraint is now
  `>=3.4.0 <5.0.0`. No library changes were needed; the `Session`, `LogLevel`
  and request-header APIs this package uses are unchanged in Serverpod 4.

## 0.5.0

- New `redactKeys`, `redactor` and `redactionPlaceholder` options on
  `ServerpodLoggerPlus.configure`. Redaction is applied ahead of both sinks, so a
  redacted value reaches neither your `LogWriter` nor Serverpod's session-log
  table. Key matching is case-insensitive and applies at any nesting depth. It
  does not scan the message string, an exception's `toString()`, or the stack
  trace.
- The string sent to `Session.log` now runs through `toJsonSafe`, matching the
  structured writers: a `DateTime`, `UuidValue` or generated model is no longer
  `toString()`-dumped into the database, and a nested map reads as JSON. Values
  containing the format's separators are quoted.
- Flattened values are capped at `flattenValueMaxLength` (default 1024,
  configurable), and the whole line is capped too. The `LogWriter` still
  receives untruncated data.
- `toJsonSafe` now stops at a maximum nesting depth, so a cyclic payload no
  longer overflows the stack.
- New `session.runWithLogger(body, labels:, payload:)`, a scoped alternative to
  `bindLogger` that restores the previous logger when the block ends.
- New exported `logSeverityRank`. `minimumLevel` filtering no longer depends on
  the declaration order of Serverpod's `LogLevel` enum.
- README: new **Where your log data goes** section, documenting that `payload`
  and `labels` are persisted on every call regardless of writer, and that
  `minimumLevel` gates only the writer.

## 0.4.1

- Documentation only: rewrote `README.md`. No library changes.

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
