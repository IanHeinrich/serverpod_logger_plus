import 'package:serverpod_logger_plus/src/flatten.dart';
import 'package:test/test.dart';

class _Point {
  _Point(this.x, this.y);
  final int x;
  final int y;
  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

class _Exploding {
  Map<String, dynamic> toJson() => throw StateError('boom');
  @override
  String toString() => 'exploding';
}

/// Indices of any UTF-16 surrogate in [text] that is not part of a valid pair.
/// A paired surrogate is legitimate - only a lone half is invalid UTF-16.
List<int> _unpairedSurrogates(String text) {
  final units = text.codeUnits;
  final bad = <int>[];
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    final isHigh = unit >= 0xD800 && unit <= 0xDBFF;
    final isLow = unit >= 0xDC00 && unit <= 0xDFFF;
    if (isHigh) {
      final next = i + 1 < units.length ? units[i + 1] : 0;
      if (next < 0xDC00 || next > 0xDFFF) bad.add(i);
    } else if (isLow) {
      final previous = i > 0 ? units[i - 1] : 0;
      if (previous < 0xD800 || previous > 0xDBFF) bad.add(i);
    }
  }
  return bad;
}

void main() {
  String flatten(
    Map<String, dynamic> payload, {
    Map<String, String> labels = const {},
    int valueMaxLength = defaultFlattenValueMaxLength,
    int totalMaxLength = defaultFlattenTotalMaxLength,
  }) =>
      flattenLogMessage(
        'msg',
        labels: labels,
        payload: payload,
        valueMaxLength: valueMaxLength,
        totalMaxLength: totalMaxLength,
      );

  group('Given flattenLogMessage', () {
    test('when there are no labels or payload, then only the message returns',
        () {
      expect(flatten(const {}), 'msg');
    });

    test('when there are labels and payload, then both sections are appended',
        () {
      expect(
        flatten(const {'userId': 7}, labels: const {'requestId': 'abc'}),
        'msg | labels: requestId=abc | payload: userId=7',
      );
    });

    test('when a payload value is a nested map, then it is rendered as JSON',
        () {
      final result = flatten(const {
        'user': {'id': 1, 'name': 'ada'}
      });

      expect(result, contains('user={"id":1,"name":"ada"}'));
      expect(result, isNot(contains('{id: 1')));
    });

    test('when a payload value is a DateTime, then it is rendered as ISO-8601',
        () {
      final result = flatten({'at': DateTime.utc(2026, 8, 26, 12, 30)});

      expect(result, contains('at=2026-08-26T12:30:00.000Z'));
    });

    test('when a payload value has toJson, then its JSON form is rendered', () {
      expect(flatten({'p': _Point(1, 2)}), contains('p={"x":1,"y":2}'));
    });

    test('when a payload value is a plain word, then it is rendered unquoted',
        () {
      expect(flatten(const {'k': 'value'}), contains('k=value'));
    });

    test('when a string value contains the entry separator, then it is quoted',
        () {
      final result = flatten(const {'k': 'a, b', 'next': 'x'});

      expect(result, contains('k="a, b"'));
      expect(result, contains('next=x'));
    });

    test(
        'when a string value contains a newline, then the result stays on one '
        'line', () {
      final result = flatten(const {'k': 'line1\nline2'});

      expect(result, isNot(contains('\n')));
      expect(result, contains(r'k="line1\nline2"'));
    });

    test(
        'when a string value contains the section separator, then it is quoted',
        () {
      expect(flatten(const {'k': 'a | b'}), contains('k="a | b"'));
    });

    test(
        'when a value exceeds valueMaxLength, then it is truncated with a '
        'marker', () {
      final result = flatten({'k': 'x' * 50}, valueMaxLength: 10);

      expect(result, contains('k=xxxxxxxxxx...[+40 chars]'));
    });

    test(
        'when truncation would split a surrogate pair, then the lone half is '
        'dropped', () {
      // Each emoji is two UTF-16 code units, so an odd cap lands mid-pair.
      final result = flatten({'k': '😀' * 10}, valueMaxLength: 5);

      expect(_unpairedSurrogates(result), isEmpty);
      expect(result, contains('😀😀'));
    });

    test('when the whole line exceeds totalMaxLength, then the line is capped',
        () {
      final payload = {for (var i = 0; i < 100; i++) 'key$i': 'value$i'};
      final result = flatten(payload, totalMaxLength: 80);

      expect(result.length, lessThan(120));
      expect(result, contains('...[+'));
    });
  });

  group('Given stringifyLogValue', () {
    test('when the value is a cyclic map, then it does not throw', () {
      final cyclic = <String, dynamic>{'name': 'root'};
      cyclic['self'] = cyclic;

      expect(() => stringifyLogValue(cyclic), returnsNormally);
      expect(stringifyLogValue(cyclic), contains('max depth exceeded'));
    });

    test('when a value toJson throws, then it falls back to toString', () {
      expect(stringifyLogValue(_Exploding()), 'exploding');
    });

    test('when the value is null, then it renders as JSON null', () {
      expect(stringifyLogValue(null), 'null');
    });

    test('when the value is an empty string, then it is quoted', () {
      expect(stringifyLogValue(''), '""');
    });

    test('when the value has surrounding whitespace, then it is quoted', () {
      expect(stringifyLogValue(' padded '), '" padded "');
    });

    test('when the value is a list, then it renders as a JSON array', () {
      expect(stringifyLogValue(const [1, 'two', true]), '[1,"two",true]');
    });

    test('when a string contains = but no separator, then it stays unquoted',
        () {
      expect(
        stringifyLogValue('https://x.test/?a=1&b=2'),
        'https://x.test/?a=1&b=2',
      );
    });
  });
}
