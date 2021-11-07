import "package:nyxx/nyxx.dart";
import "package:running_on_dart/src/internal/db.dart" show dbStarted;
import "package:running_on_dart/src/internal/utils.dart" show enabledIntentFeatures;
import "package:running_on_dart/src/modules/settings/settings.dart" show fetchFeatureSettings, nickNamePoopingSettingName;

const _poopEmoji = "💩";
final _poopRegexp = RegExp(r"[!#@^%&-*\.+']");

Future<void> poopNickName(IMember member) async {
  final user = await member.user.getOrDownload();

  final nickName = member.nickname?.trim() ?? user.username;

  if (nickName.startsWith(_poopRegexp)) {
    await member.edit(nick: _poopEmoji);
  }
}

Future<void> nicknamePoopUpdateEvent(IGuildMemberUpdateEvent event) async {
  if (!dbStarted) {
    return;
  }

  final poopFeature = await fetchFeatureSettings(event.guild.id, nickNamePoopingSettingName);
  if (poopFeature == null || !enabledIntentFeatures) {
    return;
  }

  await poopNickName(await event.member.getOrDownload());
}

Future<void> nicknamePoopJoinEvent(IGuildMemberAddEvent event) async {
  if (!dbStarted) {
    return;
  }

  final poopFeature = await fetchFeatureSettings(event.guild.id, nickNamePoopingSettingName);
  if (poopFeature == null || !enabledIntentFeatures) {
    return;
  }

  await poopNickName(event.member);
}