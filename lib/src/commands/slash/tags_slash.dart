import 'dart:async';

import "package:nyxx/nyxx.dart";
import "package:nyxx_interactions/nyxx_interactions.dart";
import "package:running_on_dart/src/modules/inline_tags.dart" as inline_tags;

Future<void> tagEditHandler(ISlashCommandInteractionEvent event) async {
  await event.acknowledge();

  final mainId = event.interaction.guild?.id ?? event.interaction.userAuthor!.id;

  final tagName = event.getArg("name").value as String;
  final tag = await inline_tags.findTagForGuild(tagName, mainId);

  if (tag == null) {
    return event.respond(MessageBuilder.content("Tag with name: `$tagName` does not exist"));
  }

  final authorId = event.interaction.guild?.id != null ? event.interaction.memberAuthor!.id : event.interaction.userAuthor!.id;

  if (tag.authorId != authorId) {
    final messageBuilder = MessageBuilder.content("You can only edit tags that are created by you. This tag was created by <@${tag.authorId}>")
      ..allowedMentions = AllowedMentions();

    return event.respond(messageBuilder, hidden: true);
  }

  final content = event.getArg("content").value.toString();
  final result = await inline_tags.updateTagForGuild(tag.id, content);
  if (!result) {
    return event.respond(MessageBuilder.content("Error occurred when editing tag. Report problem to developer"), hidden: true);
  }

  return event.respond(MessageBuilder.content("Tag `${tag.name}` edited successfully with content: `$content`"));
}

Future<void> tagSearchHandler(ISlashCommandInteractionEvent event) async {
  await event.acknowledge(hidden: true);

  final mainId = event.interaction.guild?.id ?? event.interaction.userAuthor!.id;

  final buffer = StringBuffer(MessageBuilder.clearCharacter);
  await for (final tag in inline_tags.findTags(mainId, event.getArg("query").value.toString())) {
    buffer.writeln("`${tag.name}` (<@${tag.authorId}>)");
  }

  final messageBuilder = MessageBuilder()
    ..allowedMentions = AllowedMentions()
    ..content = buffer.toString();

  await event.respond(messageBuilder, hidden: true);
}

Future<void> tagStatsHandler(ISlashCommandInteractionEvent event) async {
  await event.acknowledge(hidden: true);

  final mainId = event.interaction.guild?.id ?? event.interaction.userAuthor!.id;
  final results = await inline_tags.fetchUsageStats(mainId);

  if (results.isEmpty) {
    await event.respond(MessageBuilder.content("No stats at the moment"));
    return;
  }

  final embed = EmbedBuilder()..description = "Tag stats";
  for (final entry in results.entries) {
    embed.addField(name: entry.key, content: "${entry.value.first} total (ephemeral: ${entry.value.last})");
  }

  final commandsUsed = await inline_tags.fetchPerDay();
  final commandsUsedString = commandsUsed == 0 ? "No commands data yet!" : commandsUsed;
  embed.addField(name: "Commands used per day (last 3 days)", content: commandsUsedString);

  return event.respond(MessageBuilder.embed(embed));
}

Future<void> showTagHandler(ISlashCommandInteractionEvent event, {required bool ephemeral}) async {
  await event.acknowledge(hidden: ephemeral);

  final mainId = event.interaction.guild?.id ?? event.interaction.userAuthor!.id;

  final tagName = event.getArg("name").value as String;
  final tag = await inline_tags.findTagForGuild(tagName, mainId);

  if (tag == null) {
    return event.respond(MessageBuilder.content("Tag with name: `$tagName` does not exist"));
  }

  await inline_tags.updateUsageStats(tag.id, ephemeral);

  return event.respond(MessageBuilder.content(tag.content));
}

Future<void> createTagHandler(ISlashCommandInteractionEvent event) async {
  await event.acknowledge();

  final tagName = event.getArg("name").value.toString();
  final tagContent = event.getArg("content").value.toString();

  final mainId = event.interaction.guild?.id ?? event.interaction.userAuthor!.id;
  final authorId = event.interaction.guild?.id != null ? event.interaction.memberAuthor!.id : event.interaction.userAuthor!.id;

  final existingTag = await inline_tags.findTagForGuild(tagName, mainId);
  if (existingTag != null) {
    return event.respond(MessageBuilder.content("Tag with that name: `$tagName` already exists!"), hidden: true);
  }

  final result = await inline_tags.createTagForGuild(tagName, tagContent, mainId, authorId);
  if (!result) {
    return event.respond(MessageBuilder.content("Error occurred when creating tag. Report problem to developer"), hidden: true);
  }

  return event.respond(MessageBuilder.content("Tag with name: `$tagName`, content: `$tagContent` created successfully"), hidden: true);
}

Future<void> deleteTagHandler(ISlashCommandInteractionEvent event) async {
  await event.acknowledge(hidden: true);

  final tagName = event.getArg("name").value.toString();
  final mainId = event.interaction.guild?.id ?? event.interaction.userAuthor!.id;
  final authorId = event.interaction.guild?.id != null ? event.interaction.memberAuthor!.id : event.interaction.userAuthor!.id;

  final tag = await inline_tags.findTagForGuild(tagName, mainId);
  if (tag == null) {
    return event.respond(MessageBuilder.content("There is no tag with name: `$tagName`"), hidden: true);
  }

  final hasManageGuildPermission = event.interaction.memberAuthorPermissions?.manageGuild == true;
  if (tag.authorId != authorId && !hasManageGuildPermission) {
    return event.respond(MessageBuilder.content("you are not owner of tag with name: `$tagName`"), hidden: true);
  }

  final result = await inline_tags.deleteTagForGuild(tag.id);
  if (!result) {
    return event.respond(MessageBuilder.content("Error occurred when deleting tag. Please report problem to developer"), hidden: true);
  }

  return event.respond(MessageBuilder.content("Tag with name: `$tagName` deleted successfully"), hidden: true);
}

FutureOr<void> tagsSearchAutocompleteHandler(IAutocompleteInteractionEvent event) async {
  final query = event.focusedOption.value.toString();
  final mainId = event.interaction.guild?.id ?? event.interaction.userAuthor!.id;

  final result = inline_tags.findTags(mainId, query).map((tag) => ArgChoiceBuilder(tag.name, tag.name));

  await event.respond(await result.toList());
}
