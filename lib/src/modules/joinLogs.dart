import "package:nyxx/nyxx.dart";
import "package:running_on_dart/src/internal/utils.dart";
import "package:running_on_dart/src/modules/settings/settings.dart";

Map<Snowflake, Snowflake> channelCache = {};

Future<void> joinLogJoinEvent(GuildMemberAddEvent event) async {
  if (!enabledIntentFeatures) {
    return;
  }

  final joinLogFeature = await fetchFeatureSettings(event.guild.id, memberJoinLogsSettingName);
  if (joinLogFeature == null) {
    return;
  }

  var channelToSendMessageTo = channelCache[joinLogFeature.guildId];
  if (channelToSendMessageTo == null) {
    if (joinLogFeature.additionalData == null) {
      return;
    }

    channelToSendMessageTo = Snowflake(joinLogFeature.additionalData);
    channelCache[joinLogFeature.guildId] = channelToSendMessageTo;
  }

  await event.member.client.httpEndpoints.sendMessage(
      channelToSendMessageTo,
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
        ..addField(name: "Joined", content: "<t:$joinedSeconds:F>", inline: true)
        ..addField(name: "Created account", content: "<t:$createdAccountSeconds:F>")
  );
}
