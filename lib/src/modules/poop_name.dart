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

final poopRegexp = RegExp("[${poopCharacters.map((c) => RegExp.escape(c)).join()}]");
final weirdCharsRegexp = RegExp(
  r'[\u200B\u200C\u200D\u2060\uFEFF\u180E\u202A-\u202E\u2066-\u2069\u00AD\u061C\uFFF9-\uFFFB\uFFFD]|[\x00-\x1F\x7F-\x9F]',
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

  Future<(bool, String?)> poopMember(Member member, {bool dryRun = true}) async {
    final memberName = member.nick ?? member.user?.globalName;
    if (memberName == null || !_shouldPoopName(memberName)) {
      return (false, null);
    }

    if (!dryRun) {
      _updateMemberWithPoopEmoji(member);
    }

    return (true, memberName);
  }

  bool _shouldPoopName(String name) => name.startsWith(poopRegexp) || weirdCharsRegexp.hasMatch(name);

  Future<void> _updateMemberWithPoopEmoji(Member member) =>
      member.update(MemberUpdateBuilder(nick: poopEmoji), auditLogReason: 'ROD PoopNameModule moderation');

  Future<bool> _isEnabledForGuild(Snowflake guildId) async {
    if (!intentFeaturesEnabled) {
      return false;
    }

    return await Injector.appInstance.get<FeatureSettingsModule>().isEnabled(Setting.poopName, guildId);
  }
}
