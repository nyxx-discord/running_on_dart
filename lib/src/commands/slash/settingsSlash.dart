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

  final featureName = event.getArg("name").value.toString();
  final targetId = event.interaction.guild?.id ?? event.interaction.userAuthor!.id;
  final whoEnabledId = event.interaction.memberAuthor?.id ?? event.interaction.userAuthor!.id;

  final featureEnabled = await fetchFeatureSettings(targetId, featureName);
  if (featureEnabled != null) {
    await event.respond(MessageBuilder.content("Feature `$featureName` is already enabled"));
    return;
  }

  try {
    await addFeatureSettings(targetId, featureName, whoEnabledId);

    await event.respond(MessageBuilder.content("Successfully enabled feature `$featureName`"));
  } on CommandExecutionException catch (e) {
    await event.respond(MessageBuilder.content(e.message));
  }
}

Future<void> disableFeatureSlash(SlashCommandInteractionEvent event) async {
  await event.acknowledge(hidden: true);

  final permissions = event.interaction.memberAuthorPermissions;
  if (permissions != null && !permissions.manageGuild) {
    await event.respond(MessageBuilder.content("You need to have manager guild permisson to use this command"));
    return;
  }

  final featureName = event.getArg("name").value.toString();
  final targetId = event.interaction.guild?.id ?? event.interaction.userAuthor!.id;

  final featureEnabled = await fetchFeatureSettings(targetId, featureName);
  if (featureEnabled != null) {
    await event.respond(MessageBuilder.content("Feature `$featureName` is not enabled"));
    return;
  }

  await deleteFeatureSettings(targetId, featureName);
  await event.respond(MessageBuilder.content("Successfully disabled feature `$featureName`"));
}

Future<void> showFeaturesSlash(SlashCommandInteractionEvent event) async {
  final targetId = event.interaction.guild?.id ?? event.interaction.userAuthor!.id;
  final features = fetchEnabledFeatureForGuild(targetId).map((event) => "`${event.name}`");

  var content = await features.join(", ");
  if (content.isEmpty) {
    content = "No features enabled yet!";
  }

  await event.respond(MessageBuilder.content(content));
}
