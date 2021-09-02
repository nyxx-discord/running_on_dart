import "package:nyxx/nyxx.dart";
import "package:nyxx_interactions/interactions.dart";
import "package:running_on_dart/src/modules/settings/settings.dart";

Future<void> enableFeatureSlash(SlashCommandInteractionEvent event) async {
  await event.acknowledge(hidden: true);

  final permissions = event.interaction.memberAuthorPermissions;
  if (permissions != null && !permissions.manageGuild) {
    await event.respond(MessageBuilder.content("You need to have manager guild permisson to use this command"));
    return;
  }

  final featureName = event.getArg("name");
  final targetId = event.interaction.guild?.id ?? event.interaction.userAuthor!.id;
  final whoEnabledId = event.interaction.memberAuthor?.id ?? event.interaction.userAuthor!.id;

  await addFeatureSettings(targetId, featureName.value.toString(), whoEnabledId);
}
