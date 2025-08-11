import 'package:test/test.dart';
import 'package:running_on_dart/src/modules/poop_name.dart';

void main() {
  group('weirdCharsRegexp', () {
    test('should catch Mathematical Alphanumeric Symbols (original examples)', () {
      final testCases = ['𝕯𝖗𝖚𝖌𝖘', '𝕾𝖚𝖌𝖆𝖗𝕾𝖊𝖆𝖓', '𝸸𝖚𝖗𝖉𝖚𝖍 ♛', '𝑇𝑟𝑎𝑣𝑖𝑠', '𝔃𝓲𝓰𝓪'];

      for (final testCase in testCases) {
        expect(
          weirdCharsRegexp.hasMatch(testCase),
          isTrue,
          reason: 'Should catch Mathematical Alphanumeric: "$testCase"',
        );
      }
    });

    test('should catch zalgo text with excessive combining marks', () {
      final testCases = [
        'ţ̴͓̺̫͓͙̹̀̔h̴͉͇̟̳̫̪͖̻̥̳͌̔̇̓̈́͗͒͌͛͛͒̕i̸̢̡̗͔͔̻̙̎̓̀̈́͒́̚ș̶̡̛̛̛̺̺͓̭̻͉̞͎̲̱̫̇͒̽͠͝į̶̧͓̰͕̻͕̰͉̈̒̔s̴̜̪͔̲͙̻͔̗̖̩̮̔͛͘̕t̸͍̥͗͌̈́͘͘͝e̴̡͚͍̓̕ş̵̰̠͕͚̲̪̙̲̥͓̯̊͊͒͂̈͋̾̇̊̊́̊͠t̴̛̪̤͓̙̩͎͊̔͆͑̉̈́̾̈́̔͝',
        'th̷̼̦̞̯̞͖̝̖͍̲̪̜̱̥̝̜͍̏̐ͩ̍ͫ̾ͭ̎̀̒̋̀ͮ̈́̽̒ͭͧͤ̾́ͫ̚̕͢͟͞͞ͅi̸̡̡̡̥͕̤͎̜̗̼̰̣̥͙ͭͭ̉̔ͩ̒͂͛ͯ̑̍ͧͣͣͩ͠͞͞ș̵̸̷̨̛̮̫͙̠̲̝͉̯̗̾̈̏͂͛̏̽̊̔̌́ͧ͊̌̆̎͆̽ͦ̈́͆̚̕͞͠͠ì̸̶̶̸̢̩̱̻͔̲͓̫̼͍̮͐ͯ̉̉ͨ̑͆͐̉̑͟͡s̨̳̖͕̟̦͍̱̳̪͌ͨͫͨ͛̈̆̆̚͢t̔́ͤ̓̓̉ͨ͢͡e͕̝͒̉̃ͥ́̋s̶̻̥̱͎͉̻͙̱ͣ́̀̔͆̇̉̌̕͜t̡̮͍͔̥ͬ͂ͣ́͊_͓̞͔̰ͭ̑̐̊ͣ',
        'a\u0300\u0301\u0302',
        'e\u0300\u0301\u0302\u0303\u0304',
      ];

      for (final testCase in testCases) {
        expect(
          weirdCharsRegexp.hasMatch(testCase),
          isTrue,
          reason: 'Should catch zalgo text: "${testCase.replaceAll(RegExp(r'[^\x20-\x7E]'), '?')}"',
        );
      }
    });

    test('should catch excessive currency symbol abuse (3+ symbols)', () {
      final testCases = ['₮₴₹test', '₮₴₹₽₪test', 'test₮₴₹name', '₮₴₹₽₪₫₡₢₣₤₥₦₧₨₩₮₯₰₱₲₳₴₵₶₷₸₹₺₻₼₽₾₿'];

      for (final testCase in testCases) {
        expect(
          excessiveCurrencyRegexp.hasMatch(testCase),
          isTrue,
          reason: 'Should catch excessive currency symbols: "$testCase"',
        );
      }
    });

    test('should NOT catch moderate currency symbol use (1-2 symbols)', () {
      final testCases = ['₮testname', 'test₴name', '₮test₴', 'user₹name₽'];

      for (final testCase in testCases) {
        expect(
          excessiveCurrencyRegexp.hasMatch(testCase),
          isFalse,
          reason: 'Should NOT catch moderate currency use: "$testCase"',
        );
      }
    });

    test('should catch extended Latin character abuse', () {
      final testCases = [
        'ⱦħīꞩīꞩⱦēꞩⱦ',
        'ĂăĄąĆćĈĉĊċČčĎďĐđĒēĔĕĖėĘęĚě',
        'ƁƂƃƄƅƆƇƈƉƊƋƌƍƎƏƐƑƒƓƔƕƖƗƘƙƚƛƜƝƞƟ',
        'ⱠⱡⱢⱣⱤⱥⱦⱧⱨⱩⱪⱫⱬⱭⱮⱯ',
        'ꜰꜱꜲꜳꜴꜵꜶꜷꜸꜹꜺꜻꜼꜽꜾꜿꝀꝁꝂꝃꝄꝅ',
      ];

      for (final testCase in testCases) {
        expect(weirdCharsRegexp.hasMatch(testCase), isTrue, reason: 'Should catch extended Latin abuse: "$testCase"');
      }
    });

    test('should preserve existing invisible character detection', () {
      final testCases = ['test\u200Bname', 'name\u202Etext', 'test\u2060name', 'name\uFEFFtext', 'test\u00ADname'];

      for (final testCase in testCases) {
        expect(
          weirdCharsRegexp.hasMatch(testCase),
          isTrue,
          reason: 'Should catch existing invisible chars: "${testCase.replaceAll(RegExp(r'[^\x20-\x7E]'), '?')}"',
        );
      }
    });

    test('should NOT catch normal usernames', () {
      final testCases = [
        'NormalUsername',
        'TestUser123',
        'regular_name',
        'user-name',
        'Valid.Name',
        'CamelCaseUser',
        'snake_case_user',
        'kebab-case-user',
        'User123',
        'SimpleTest',
        'café',
        'naïve',
        'résumé',
      ];

      for (final testCase in testCases) {
        expect(weirdCharsRegexp.hasMatch(testCase), isFalse, reason: 'Should NOT catch normal username: "$testCase"');
      }
    });

    test('should catch ASCII control characters', () {
      final testCases = ['test\x00name', 'test\x1Fname', 'test\x7Fname', 'test\x9Fname'];

      for (final testCase in testCases) {
        expect(
          weirdCharsRegexp.hasMatch(testCase),
          isTrue,
          reason: 'Should catch ASCII control chars: "${testCase.replaceAll(RegExp(r'[^\x20-\x7E]'), '?')}"',
        );
      }
    });
  });

  group('Combined detection logic (replicates _shouldPoopName)', () {
    test('should detect usernames that start with poop chars OR have weird chars OR excessive currency', () {
      final shouldBeDetected = [
        '.username',
        '!username',
        '@username',
        '(username',
        '𝕯𝖗𝖚𝖌𝖘',
        'test𝑇𝑟𝑎𝑣𝑖𝑠',
        'ţ̴͓̺̫͓͙̹̀̔end',
        'ⱦħīꞩtest',
        'test\u200Bname',
        '₮₴₹test',
        'user₮₴₹₽name',
      ];

      for (final username in shouldBeDetected) {
        final startsWithPoop = username.startsWith(poopRegexp);
        final hasWeirdChars = weirdCharsRegexp.hasMatch(username);
        final hasExcessiveCurrency = excessiveCurrencyRegexp.hasMatch(username);
        final shouldPoop = startsWithPoop || hasWeirdChars || hasExcessiveCurrency;

        expect(
          shouldPoop,
          isTrue,
          reason:
              'Should detect problematic username: "${username.length > 20 ? '${username.substring(0, 20)}...' : username}"',
        );
      }
    });

    test('should NOT detect normal usernames', () {
      final shouldNotBeDetected = [
        'NormalUser',
        'TestUser123',
        'valid_name',
        'CamelCase',
        'legitimate-name',
        'User.Name',
        'café',
        'résumé',
        'username.test',
        'user!test',
        '₮testname',
        'user₴name',
      ];

      for (final username in shouldNotBeDetected) {
        final startsWithPoop = username.startsWith(poopRegexp);
        final hasWeirdChars = weirdCharsRegexp.hasMatch(username);
        final hasExcessiveCurrency = excessiveCurrencyRegexp.hasMatch(username);
        final shouldPoop = startsWithPoop || hasWeirdChars || hasExcessiveCurrency;

        expect(shouldPoop, isFalse, reason: 'Should NOT detect normal username: "$username"');
      }
    });
  });

  group('Edge cases and performance', () {
    test('should handle empty and null strings gracefully', () {
      expect(weirdCharsRegexp.hasMatch(''), isFalse);
      expect(weirdCharsRegexp.hasMatch('a'), isFalse);
    });

    test('should handle very long strings', () {
      final longNormal = 'a' * 1000;
      final longProblematic = '𝑎' * 100;

      expect(weirdCharsRegexp.hasMatch(longNormal), isFalse);
      expect(weirdCharsRegexp.hasMatch(longProblematic), isTrue);
    });

    test('should detect problematic characters anywhere in string', () {
      expect(weirdCharsRegexp.hasMatch('start𝑎end'), isTrue);
      expect(weirdCharsRegexp.hasMatch('startⱦend'), isTrue);
      expect(excessiveCurrencyRegexp.hasMatch('start₮₴₹end'), isTrue);
    });
  });
}
