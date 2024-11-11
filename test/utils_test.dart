import 'package:running_on_dart/src/util/util.dart';
import 'package:test/test.dart';

void main() {
  test("random color test", () {
    final color = getRandomColor();
    final secondColor = getRandomColor();

    expect(color, isNot(secondColor));
    expect(color, color);
  });

  group("FormatShortDurationExtension", () {
    test("Minutes and second", () {
      final duration = Duration(minutes: 2, seconds: 56);

      expect(duration.formatShort(), '00:02:56');
    });

    test("Hours, minutes and second", () {
      final duration = Duration(hours: 10, minutes: 2, seconds: 56);

      expect(duration.formatShort(), '10:02:56');
    });
  });

  group("valueOrNull", () {
    test("value exists", () {
      expect(valueOrNull('value'), 'value');
    });

    test("whitespace", () {
      expect(valueOrNull('  '), isNull);
    });

    test("null value", () {
      expect(valueOrNull(null), isNull);
    });
  });

  group("getDurationFromStringOrDefault", () {
    test("value exists", () {
      expect(getDurationFromStringOrDefault("2 minutes"), Duration(minutes: 2));
    });

    test("value null", () {
      expect(getDurationFromStringOrDefault(null, Duration(seconds: 1)), Duration(seconds: 1));
    });

    test("value null and default null", () {
      expect(getDurationFromStringOrDefault(null, null), isNull);
    });
  });
}
