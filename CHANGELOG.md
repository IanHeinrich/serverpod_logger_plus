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
