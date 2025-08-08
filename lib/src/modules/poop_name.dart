import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/modules/feature_settings.dart';
import 'package:running_on_dart/src/settings.dart';
import 'package:running_on_dart/src/init.dart';

const poopEmoji = "💩";
const poopCharacters = [
  '(',
  ')',
  '-',
  '+',
  '=',
  '_',
  ']',
  '[',
  '\\',
  '|',
  ';',
  "'",
  ',',
  '.',
  '<',
  '>',
  '/',
  '?',
  '!',
  '@',
  '#',
  r'$',
  '%',
  '^',
  '&',
  '*',
];

const minimalPoopCharacters = ['.', "'", '<', '[', '!', '@', r'$', '^', '*'];

final poopRegexp = RegExp("[${poopCharacters.map((c) => RegExp.escape(c)).join()}]");

/// Detects problematic characters in usernames including:
/// - Invisible/control characters (zero-width spaces, direction overrides, etc.)
/// - ASCII control characters
/// - Mathematical Alphanumeric Symbols (U+1D400-U+1D7FF) - catches fancy Unicode text like "𝕯𝖗𝖚𝖌𝖘", "𝑇𝑟𝑎𝑣𝑖𝑠"
/// - Excessive combining marks (3+ in sequence) - catches zalgo text like "ţ̴͓̺̫͓͙̹̀̔h̴͉͇̟̳̫̪͖̻̥̳͌̔̇̓̈́͗͒͌͛͛͒̕i̸̢̡̗͔͔̻̙̎̓̀̈́͒́̚ș̶̡̛̛̛̺̺͓̭̻͉̞͎̲̱̫̇͒̽͠͝"
/// - Extended Latin characters - catches obscure Latin variants like "ⱦħīꞩīꞩⱦēꞩⱦ"
final weirdCharsRegexp = RegExp(
  r'[\u200B\u200C\u200D\u2060\uFEFF\u180E\u202A-\u202E\u2066-\u2069\u00AD\u061C\uFFF9-\uFFFB\uFFFD]'
  r'|[\x00-\x1F\x7F-\x9F]'
  r'|[\u{1D400}-\u{1D7FF}]' // Mathematical Alphanumeric Symbols
  r'|[\u{0300}-\u{036F}]{3,}' // 3+ combining marks (zalgo text)
  r'|[\u{0100}-\u{017F}]' // Latin Extended-A
  r'|[\u{0180}-\u{024F}]' // Latin Extended-B
  r'|[\u{2C60}-\u{2C7F}]' // Latin Extended-C
  r'|[\u{A720}-\u{A7FF}]', // Latin Extended-D
  unicode: true,
);

/// Detects excessive currency symbol abuse (3+ currency symbols in username)
final excessiveCurrencyRegexp = RegExp(
  r'([\u{20A0}-\u{20CF}].*){3,}', // 3+ currency symbols anywhere in string
  unicode: true,
);

class PoopNameModule implements RequiresInitialization {
  final NyxxGateway _client = Injector.appInstance.get();

  @override
  Future<void> init() async {
    _client.onGuildMemberAdd.listen((event) => _handle(event.member));
    _client.onGuildMemberUpdate.listen((event) => _handle(event.member));
  }

  void _handle(Member member) async {
    final isEnabled = await _isEnabledForGuild(member.manager.guildId);
    if (!isEnabled) {
      return;
    }

    poopMember(member, dryRun: false);
  }

  Future<bool> poopMember(Member member, {bool dryRun = true}) async {
    final memberName = getMemberNameForPooping(member);
    if (memberName == null || !_shouldPoopName(memberName)) {
      return false;
    }

    if (!dryRun) {
      _updateMemberWithPoopEmoji(member);
    }

    return true;
  }

  bool _shouldPoopName(String name) =>
      name.startsWith(poopRegexp) || weirdCharsRegexp.hasMatch(name) || excessiveCurrencyRegexp.hasMatch(name);

  String? getMemberNameForPooping(Member member) => member.nick ?? member.user?.globalName ?? member.user?.username;

  Future<void> _updateMemberWithPoopEmoji(Member member) =>
      member.update(MemberUpdateBuilder(nick: poopEmoji), auditLogReason: 'ROD PoopNameModule moderation');

  Future<bool> _isEnabledForGuild(Snowflake guildId) async {
    if (!intentFeaturesEnabled) {
      return false;
    }

    return await Injector.appInstance.get<FeatureSettingsModule>().isEnabled(Setting.poopName, guildId);
  }
}
