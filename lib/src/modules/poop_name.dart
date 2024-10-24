import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/services/feature_settings.dart';
import 'package:running_on_dart/src/settings.dart';
import 'package:running_on_dart/src/util/util.dart';

const poopEmoji = "💩";
final poopCharacters = ['!', '#', '@', '^', '%', '&', '-', '*', '.' '+', '\''];
final poopRegexp = RegExp("[${poopCharacters.join()}]");

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
    final memberName = member.nick ?? member.user?.globalName ?? '';
    if (!_shouldPoopName(memberName)) {
      return (false, null);
    }

    if (!dryRun) {
      _updateMemberWithPoopEmoji(member);
    }

    return (true, memberName);
  }

  bool _shouldPoopName(String name) => name.startsWith(poopRegexp);

  Future<void> _updateMemberWithPoopEmoji(Member member) =>
      member.update(MemberUpdateBuilder(nick: poopEmoji), auditLogReason: 'ROD PoopNameModule moderation');

  Future<bool> _isEnabledForGuild(Snowflake guildId) async {
    if (!intentFeaturesEnabled) {
      return false;
    }

    return await Injector.appInstance.get<FeatureSettingsService>().isEnabled(Setting.poopName, guildId);
  }
}
