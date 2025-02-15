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

  group("Utility Functions (New Tests)", () {  // Group for the new tests

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

    test('generateRandomString generates a random string of given length', () {
      final randomString = generateRandomString(10);
      expect(randomString.length, 10);
      expect(randomString, matches(RegExp(r'^[A-Za-z0-9]+$')));
    });

    test('spliceEmbedsForMessageBuilders splits embeds into chunks', () {
      final embeds = [EmbedBuilder(), EmbedBuilder(), EmbedBuilder(), EmbedBuilder()];
      final messageBuilders = spliceEmbedsForMessageBuilders(embeds, 2).toList();
      expect(messageBuilders.length, 2);
      expect(messageBuilders[0].embeds?.length, 2);
      expect(messageBuilders[1].embeds?.length, 2);
    });

    test('stripNonAscii removes non-ASCII characters (extended)', () {
      expect(stripNonAscii('test\u00A0test'), 'testtest');
    });

    test('boolValue converts values to boolean', () {
      expect(boolValue(true), isTrue);
      expect(boolValue(1), isTrue);
      expect(boolValue('1'), isTrue);
      expect(boolValue('yes'), isTrue);
      expect(boolValue('true'), isTrue);
      expect(boolValue(false), isFalse);
      expect(boolValue(0), isFalse);
      expect(boolValue('0'), isFalse);
      expect(boolValue('no'), isFalse);
      expect(boolValue('false'), isFalse);
      expect(boolValue('test'), isFalse);
    });

    test('boolToString converts boolean to string', () {
      expect(boolToString(true), 'true');
      expect(boolToString(false), 'false');
    });
  });
}
