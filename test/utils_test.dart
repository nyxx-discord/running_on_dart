import 'package:running_on_dart/src/util/util.dart';
import 'package:test/test.dart';
import 'package:nyxx/nyxx.dart';

void main() {
  test("random color test", () {
    final color = getRandomColor();
    final secondColor = getRandomColor();

    expect(color, isNot(secondColor));
    expect(color.value, inInclusiveRange(0, 0xFFFFFFFF));
  });

  test("strip non ascii characters", () {
    expect('This is test ', stripNonAscii('This śis test 言葉にせずとも'));
  });

  group("FormatShortDurationExtension", () {
    group("formatShort", () {
      test("Minutes and second", () {
        final duration = Duration(minutes: 2, seconds: 56);
        expect(duration.formatShort(), '00:02:56');
      });

      test("Hours, minutes and second", () {
        final duration = Duration(hours: 10, minutes: 2, seconds: 56);
        expect(duration.formatShort(), '10:02:56');
      });
    });

    group("formatShort", () {
      test('should return fallback for zero duration', () {
        const duration = Duration.zero;
        expect(duration.formatReadable(), equals('Less than a minute'));
      });

      test('should format minutes only (less than an hour)', () {
        const duration = Duration(minutes: 45);
        expect(duration.formatReadable(), equals('45 mins'));
      });

      test('should format hours only when minutes and days are zero', () {
        const duration = Duration(hours: 5);
        expect(duration.formatReadable(), equals('5 hours'));
      });

      test('should format hours and minutes together', () {
        const duration = Duration(hours: 3, minutes: 15);
        expect(duration.formatReadable(), equals('3 hours, 15 mins'));
      });

      test('should include exactly 1 day correctly', () {
        const duration = Duration(days: 1);
        expect(duration.formatReadable(), equals('1 days'));
      });

      test('should properly split days, hours, and minutes', () {
        const duration = Duration(days: 3, hours: 4, minutes: 20);
        expect(duration.formatReadable(), equals('3 days, 4 hours, 20 mins'));
      });

      test('should omit hours if they are 0 but days and minutes exist', () {
        const duration = Duration(days: 2, minutes: 30);
        expect(duration.formatReadable(), equals('2 days, 30 mins'));
      });

      test('should omit minutes if they are 0 but days and hours exist', () {
        const duration = Duration(days: 2, hours: 5);
        expect(duration.formatReadable(), equals('2 days, 5 hours'));
      });
    });
  });

  group("valueOrNull", () {
    test("value exists", () {
      expect(valueOrNull('value'), 'value');
    });

    test("whitespace", () {
      expect(valueOrNull('  '), isNull);
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

  group("Utility Functions (New Tests)", () {
    test('getCurrentMemoryString returns a string with memory usage', () {
      final memoryString = getCurrentMemoryString();
      expect(memoryString, matches(RegExp(r'^\d+\.\d+/\d+\.\d+ MB$')));
    });

    test('getDartPlatform returns the Dart platform', () {
      final platform = getDartPlatform();
      expect(platform, isNotEmpty);
    });

    test('ToMapExtension converts Iterable<MapEntry> to Map', () {
      final entries = [MapEntry('a', 1), MapEntry('b', 2)];
      final map = entries.toMap();
      expect(map, {'a': 1, 'b': 2});
    });

    test('generateRandomString generates a random string of given length and uppercases', () {
      final randomString = generateRandomString(10);
      expect(randomString.length, 10);
      expect(randomString, matches(RegExp(r'^[A-Z0-9]+$')));
    });

    test('spliceEmbedsForMessageBuilders splits embeds into chunks (default size 2)', () {
      final embeds = [EmbedBuilder(), EmbedBuilder(), EmbedBuilder()];
      final messageBuilders = spliceEmbedsForMessageBuilders(embeds).toList();
      expect(messageBuilders.length, 2);
      expect(messageBuilders[0].embeds?.length, 2);
      expect(messageBuilders[1].embeds?.length, 1);
    });

    test('spliceEmbedsForMessageBuilders splits embeds with custom slice size', () {
      final embeds = [EmbedBuilder(), EmbedBuilder(), EmbedBuilder(), EmbedBuilder(), EmbedBuilder()];
      final messageBuilders = spliceEmbedsForMessageBuilders(embeds, 3).toList();
      expect(messageBuilders.length, 2);
      expect(messageBuilders[0].embeds?.length, 3);
      expect(messageBuilders[1].embeds?.length, 2);
    });

    test('stripNonAscii removes non-ASCII characters (extended)', () {
      expect(stripNonAscii('test\u00A0test'), 'testtest');
      expect(stripNonAscii('żźćńółęąś🐍'), '');
      expect(stripNonAscii('ASCII_only_123'), 'ASCII_only_123');
      expect(stripNonAscii('Hello\u200BWorld'), 'HelloWorld');
    });

    test('boolValue converts values to boolean', () {
      expect(boolValue(true), isTrue);
      expect(boolValue(1), isTrue);
      expect(boolValue(2), isTrue);
      expect(boolValue('1'), isTrue);
      expect(boolValue('yes'), isTrue);
      expect(boolValue('true'), isTrue);
      expect(boolValue(false), isFalse);
      expect(boolValue(0), isFalse);
      expect(boolValue(-1), isFalse);
      expect(boolValue('0'), isFalse);
      expect(boolValue('no'), isFalse);
      expect(boolValue('false'), isFalse);
      expect(boolValue(' test '), isFalse);
      expect(boolValue(null), isFalse);
    });

    test('boolToString converts boolean to string', () {
      expect(boolToString(true), 'true');
      expect(boolToString(false), 'false');
    });
  });

  group("Additional utils edge cases", () {
    test('spliceEmbedsForMessageBuilders with empty list yields no messages', () {
      final result = spliceEmbedsForMessageBuilders(const <EmbedBuilder>[]).toList();
      expect(result, isEmpty);
    });

    test('getDurationFromStringOrDefault invalid string returns default', () {
      expect(getDurationFromStringOrDefault('not a duration', const Duration(seconds: 5)), const Duration(seconds: 5));
    });

    test('valueOrNull returns original non-empty string (not trimmed)', () {
      expect(valueOrNull(' value '), ' value ');
    });

    test('generateRandomString supports zero length', () {
      expect(generateRandomString(0), '');
    });
  });
}
