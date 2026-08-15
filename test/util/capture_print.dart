import 'dart:async';

/// Runs [body] inside a zone that intercepts `print()` calls, returning every
/// line that was printed instead of letting it reach real stdout.
///
/// Used to assert on the exact JSON emitted by structured [LogWriter]s
/// without spawning a process or touching real stdout.
Future<List<String>> capturePrints(Future<void> Function() body) async {
  final lines = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return lines;
}
