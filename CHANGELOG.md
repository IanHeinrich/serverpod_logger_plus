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
