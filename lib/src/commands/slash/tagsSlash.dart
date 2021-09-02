import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/interactions.dart';
import 'package:running_on_dart/src/modules/inline_tags.dart' as inline_tags;

Future<void> tagStatsHandler(SlashCommandInteractionEvent event) async {
  await event.acknowledge(hidden: true);

  if (event.interaction.guild == null) {
    await event.respond(MessageBuilder.content("Message cannot be executed in DMs"));
    return;
  }

  final mainId = event.interaction.guild?.id ?? event.interaction.userAuthor!.id;
  final results = await inline_tags.fetchUsageStats(mainId);

  if (results.isEmpty) {
    await event.respond(MessageBuilder.content("No stats at the moment"));
    return;
  }

  final embed = EmbedBuilder()
    ..description = "Tag stats";
  for (final entry in results.entries) {
    embed.addField(name: entry.key, content: "${entry.value.first} total (ephemeral: ${entry.value.last})");
  }

  final commandsUsed = await inline_tags.fetchPerDay();
  final commandsUsedString = commandsUsed == 0
      ? "No commands data yet!"
      : commandsUsed;
  embed.addField(name: "Commands used per day (last 3 days)", content: commandsUsedString);

  return event.respond(MessageBuilder.embed(embed));
}

Future<void> showTagHandler(SlashCommandInteractionEvent event, {required bool ephemeral}) async {
  await event.acknowledge(hidden: ephemeral);

  final mainId = event.interaction.guild?.id ?? event.interaction.userAuthor!.id;

  final tagName = event.interaction.options.first.args.firstWhere((element) => element.name == "name").value.toString();
  final tag = await inline_tags.findTagForGuild(tagName, mainId);

  if (tag == null) {
    return event.respond(MessageBuilder.content("Tag with name: `$tagName` does not exist"));
  }

  await inline_tags.updateUsageStats(tag.id, ephemeral);

  return event.respond(MessageBuilder.content(tag.content));
}

Future<void> createTagHandler(SlashCommandInteractionEvent event) async {
  await event.acknowledge();

  final tagName = (event.interaction.options.first.args.firstWhere((element) => element.name == "name")).value.toString();
  final tagContent = (event.interaction.options.first.args.firstWhere((element) => element.name == "content")).value.toString();
  final mainId = event.interaction.guild?.id ?? event.interaction.userAuthor!.id;
  final authorId = event.interaction.guild?.id != null
      ? event.interaction.memberAuthor!.id
      : event.interaction.userAuthor!.id;

  final existingTag = await inline_tags.findTagForGuild(tagName, mainId);
  if (existingTag != null) {
    return event.respond(MessageBuilder.content("Tag with that name already exists!"), hidden: true);
  }

  final result = await inline_tags.createTagForGuild(tagName, tagContent, mainId, authorId);
  if (!result) {
    return event.respond(MessageBuilder.content("Error occurred when creating tag. Report problem to developer"), hidden: true);
  }

  return event.respond(MessageBuilder.content("Tag created successfully"), hidden: true);
}

Future<void> deleteTagHandler(SlashCommandInteractionEvent event) async {
  await event.acknowledge();

  final tagName = event.interaction.options.first.args.firstWhere((element) => element.name == "name").value.toString();
  final mainId = event.interaction.guild?.id ?? event.interaction.userAuthor!.id;
  final authorId = event.interaction.guild?.id != null
      ? event.interaction.memberAuthor!.id
      : event.interaction.userAuthor!.id;

  final result = await inline_tags.deleteTagForGuild(tagName, mainId, authorId);
  if (!result) {
    return event.respond(MessageBuilder.content("Error occurred when deleting tag. Report problem to developer"), hidden: true);
  }

  return event.respond(MessageBuilder.content("Tag deleted successfully"), hidden: true);
}