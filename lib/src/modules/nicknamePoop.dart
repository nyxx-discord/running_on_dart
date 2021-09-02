import "package:nyxx/nyxx.dart";
import "package:running_on_dart/src/modules/settings/settings.dart";

const _poopEmoji = "💩";
final _poopRegexp = RegExp(r"[!#@^%&-*\.+']");

Future<void> poopNickName(Member member) async {
  final nickName = member.nickname?.trim();

  if (nickName == null) {
    return;
  }

  if (nickName.startsWith(_poopRegexp)) {
    await member.edit(nick: _poopEmoji);
  }
}

Future<void> nicknamePoopUpdateEvent(GuildMemberUpdateEvent event) async {
  final poopFeature = await fetchFeatureSettings(event.guild.id, nickNamePoopingSettingName);
  if (poopFeature == null) {
    return;
  }

  await poopNickName(await event.member.getOrDownload());
}

Future<void> nicknamePoopJoinEvent(GuildMemberAddEvent event) async {
  final poopFeature = await fetchFeatureSettings(event.guild.id, nickNamePoopingSettingName);
  if (poopFeature == null) {
    return;
  }

  await poopNickName(event.member);
}
