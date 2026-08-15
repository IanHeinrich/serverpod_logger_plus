import 'package:serverpod/serverpod.dart';

/// Signature for a custom trace-context extractor passed to
/// `ServerpodLoggerPlus.configure`. Given the session, return `traceId`/
/// `spanId` (and any other label keys) to bind, or an empty map to bind
/// nothing. Call [extractTraceContext] inside your own if you want to keep the
/// built-in header parsing as a fallback.
typedef TraceContextExtractor = Map<String, String> Function(Session session);

/// Extracts distributed-trace context from the request headers of [session].
///
/// Serverpod does not propagate standard trace headers itself, so this reads
/// them off the incoming request when one exists (`MethodCallSession` and
/// other request-backed sessions; `null` for internal/future-call sessions).
/// Returns `traceId`/`spanId` as labels, or an empty map when no request or no
/// recognized header is present.
Map<String, String> extractTraceContext(Session session) {
  final request = session.request;
  if (request == null) return const {};
  final headers = request.headers;
  return traceContextFromHeaders((name) {
    final values = headers[name];
    if (values == null) return null;
    for (final value in values) {
      if (value.isNotEmpty) return value;
    }
    return null;
  });
}

/// Parses trace context from a header [lookup] (a case-insensitive header name
/// to its first non-empty value), trying the W3C, GCP, AWS X-Ray, and Datadog
/// formats in that order and returning the first that matches.
Map<String, String> traceContextFromHeaders(
  String? Function(String name) lookup,
) {
  // W3C Trace Context: traceparent = version-traceId-spanId-flags.
  final traceparent = lookup('traceparent');
  if (traceparent != null) {
    final parts = traceparent.split('-');
    if (parts.length >= 4) {
      final traceId = parts[1];
      final spanId = parts[2];
      // An all-zero trace or span id is invalid per the W3C spec; skip it and
      // fall through to the other formats.
      final validTraceId = traceId.isNotEmpty && !_isAllZeros(traceId);
      final validSpanId = spanId.isNotEmpty && !_isAllZeros(spanId);
      if (validTraceId && validSpanId) {
        return {'traceId': traceId, 'spanId': spanId};
      }
    }
  }

  // GCP Cloud Trace: X-Cloud-Trace-Context = TRACE_ID/SPAN_ID;o=1.
  final gcp = lookup('x-cloud-trace-context');
  if (gcp != null && gcp.isNotEmpty) {
    final slash = gcp.indexOf('/');
    final traceId = slash >= 0 ? gcp.substring(0, slash) : gcp;
    var spanId = '';
    if (slash >= 0) {
      final rest = gcp.substring(slash + 1);
      final semicolon = rest.indexOf(';');
      spanId = semicolon >= 0 ? rest.substring(0, semicolon) : rest;
    }
    if (traceId.isNotEmpty) {
      return {
        'traceId': traceId,
        if (spanId.isNotEmpty) 'spanId': spanId,
      };
    }
  }

  // AWS X-Ray: X-Amzn-Trace-Id = Root=...;Parent=...;Sampled=1.
  final aws = lookup('x-amzn-trace-id');
  if (aws != null) {
    String? root;
    String? parent;
    for (final segment in aws.split(';')) {
      final separator = segment.indexOf('=');
      if (separator < 0) continue;
      final key = segment.substring(0, separator).trim();
      final value = segment.substring(separator + 1).trim();
      if (key == 'Root') root = value;
      if (key == 'Parent') parent = value;
    }
    if (root != null && root.isNotEmpty) {
      return {
        'traceId': root,
        if (parent != null && parent.isNotEmpty) 'spanId': parent,
      };
    }
  }

  // Datadog: x-datadog-trace-id / x-datadog-parent-id (separate headers).
  final datadogTrace = lookup('x-datadog-trace-id');
  if (datadogTrace != null && datadogTrace.isNotEmpty) {
    final datadogParent = lookup('x-datadog-parent-id');
    return {
      'traceId': datadogTrace,
      if (datadogParent != null && datadogParent.isNotEmpty)
        'spanId': datadogParent,
    };
  }

  return const {};
}

bool _isAllZeros(String value) {
  for (final unit in value.codeUnits) {
    if (unit != 0x30) return false;
  }
  return true;
}
