import "package:nyxx/nyxx.dart" show EmbedBuilder, GuildMemberAddEvent, Member, MessageBuilder, Snowflake, User;
import "package:running_on_dart/src/internal/utils.dart" show enabledIntentFeatures;
import "package:running_on_dart/src/modules/settings/settings.dart" show fetchFeatureSettings, memberJoinLogsSettingName;

Future<void> joinLogJoinEvent(GuildMemberAddEvent event) async {
  if (!enabledIntentFeatures) {
    return;
  }

  final joinLogFeature = await fetchFeatureSettings(event.guild.id, memberJoinLogsSettingName);
  if (joinLogFeature == null) {
    return;
  }

  await event.member.client.httpEndpoints.sendMessage(
      Snowflake(joinLogFeature.additionalData!),
      _getBuilderForMember(event.member, event.user)
  );
}

MessageBuilder _getBuilderForMember(Member member, User user) {
  final joinedSeconds = (DateTime.now().millisecondsSinceEpoch / 1000).round();
  final createdAccountSeconds = (user.id.timestamp.millisecondsSinceEpoch / 1000).round();

  return MessageBuilder.embed(
      EmbedBuilder()
        ..description = "**Member joined**"
        ..addAuthor((author) {
          author.iconUrl = user.avatarURL();
          author.name = user.tag;
        })
        ..addField(name: "ID", content: user.id, inline: true)
        ..addField(name: "Joined", content: "<t:$joinedSeconds:d> (<t:$joinedSeconds:R>)", inline: true)
        ..addField(name: "Created account", content: "<t:$createdAccountSeconds:d> (<t:$createdAccountSeconds:R>)")
  );
}
