import "package:nyxx/nyxx.dart" show MessageBuilder;
import "package:nyxx_interactions/interactions.dart" show SlashCommandInteractionEvent;
import "package:running_on_dart/src/modules/settings/settings.dart" show CommandExecutionException, addFeatureSettings, deleteFeatureSettings, featureSettingsThatNeedsAdditionalData, fetchEnabledFeatureForGuild, fetchFeatureSettings;

Future<void> listFeaturesSlash(SlashCommandInteractionEvent event) async {
  await event.acknowledge(hidden: true);

  final targetId = event.interaction.guild?.id ?? event.interaction.userAuthor!.id;

  final buffer = StringBuffer();

  await for (final feature in fetchEnabledFeatureForGuild(targetId)) {
    buffer.writeln("${feature.name} (${feature.additionalData ?? "(empty)"})");
  }

  await event.respond(MessageBuilder.content("```${buffer.toString()}```"));
}

Future<void> enableFeatureSlash(SlashCommandInteractionEvent event) async {
  await event.acknowledge(hidden: true);

  final permissions = event.interaction.memberAuthorPermissions;
  if (permissions != null && !permissions.manageGuild) {
    await event.respond(MessageBuilder.content("You need to have manage guild permisson to use this command"));
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

  String? additionalData;
  try {
    additionalData = event.getArg("data").value.toString();
  } on StateError {
    if (featureSettingsThatNeedsAdditionalData.containsKey(featureName)) {
      return event.respond(MessageBuilder.content("That feature requires to provide additional data"));
    }
  }

  try {
    await addFeatureSettings(targetId, featureName, whoEnabledId, additionalData: additionalData);

    await event.respond(MessageBuilder.content("Successfully enabled feature `$featureName`"));
  } on CommandExecutionException catch (e) {
    await event.respond(MessageBuilder.content(e.message));
  }
}

Future<void> disableFeatureSlash(SlashCommandInteractionEvent event) async {
  await event.acknowledge(hidden: true);

  final permissions = event.interaction.memberAuthorPermissions;
  if (permissions != null && !permissions.manageGuild) {
    await event.respond(MessageBuilder.content("You need to have manage guild permission to use this command"));
    return;
  }

  final featureName = event.getArg("name").value.toString();
  final targetId = event.interaction.guild?.id ?? event.interaction.userAuthor!.id;

  final featureEnabled = await fetchFeatureSettings(targetId, featureName);
  if (featureEnabled == null) {
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
