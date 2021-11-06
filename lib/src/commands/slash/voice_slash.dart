import "package:nyxx/nyxx.dart" show MessageBuilder, Snowflake;
import "package:nyxx_interactions/interactions.dart" show SlashCommandInteractionEvent;
import "package:running_on_dart/src/commands/voice_common.dart" show joinChannel, leaveChannel;
import "package:running_on_dart/src/modules/settings/settings.dart" show privilegedAdminSnowflakes;

Future<void> joinVoiceHandler(SlashCommandInteractionEvent event) async {
  await event.acknowledge();

  final author = event.interaction.memberAuthor;
  if (author == null || !privilegedAdminSnowflakes.contains(author.id.id)) {
    await event.respond(MessageBuilder.content("You don't have permissions to do that"), hidden: true);
  }

  final channel = event.getArg("channel").value.toString();
  await joinChannel(event.interaction.guild!.id, Snowflake(channel), event.client);

  await event.respond(MessageBuilder.content("Channel joined!"));
}

Future<void> leaveVoiceHandler(SlashCommandInteractionEvent event) async {
  await event.acknowledge();

  final author = event.interaction.memberAuthor;
  if (author == null || !privilegedAdminSnowflakes.contains(author.id.id)) {
    await event.respond(MessageBuilder.content("You don't have permissions to do that"), hidden: true);
  }

  await leaveChannel(event.interaction.guild!.id, event.client);
  await event.respond(MessageBuilder.content("Left channel!"));
}
