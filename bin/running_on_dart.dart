/*
Configuration via utils.environment variables:
  ROD_PREFIX - prefix that bot will use for commands
  ROD_TOKEN - bot token to login
  ROD_ADMIN_ID - id of admin
*/

import "dart:math" show Random;

import "package:http/http.dart" as http;
import "package:nyxx/nyxx.dart" show CacheOptions, CachePolicyLocation, ClientOptions, Constants, DiscordColor, EmbedBuilder, EmbedFooterBuilder, GatewayIntents, MessageBuilder, Nyxx, Snowflake, TextChannel, TextGuildChannel;
import "package:nyxx_commander/commander.dart" show CommandContext, CommandGroup, Commander;
import "package:nyxx_interactions/interactions.dart";
import "package:time_ago_provider/time_ago_provider.dart" show formatFull;

import "modules/docs.dart" as docs;
// import "modules/exec.dart" as exec;
import "modules/inline_tags.dart" as inline_tags;
import "utils/db/db.dart" as db;
import "utils/utils.dart" as utils;

late Nyxx botInstance;

void main(List<String> arguments) async {
  db.openDbAndRunMigrations();

  final cacheOptions = CacheOptions()
    ..memberCachePolicyLocation = CachePolicyLocation.none()
    ..userCachePolicyLocation = CachePolicyLocation.none();

  botInstance = Nyxx(
      utils.envToken!,
      GatewayIntents.allUnprivileged,
      options: ClientOptions(guildSubscriptions: false),
      cacheOptions: cacheOptions
  );

  Commander(botInstance, prefix: utils.envPrefix)
    // Docs commands
    ..registerCommandGroup(CommandGroup(name: "docs")
      ..registerDefaultCommand(docsCommand)
      ..registerSubCommand("get", docsGetCommand)
      ..registerSubCommand("search", docsSearchCommand))
    // Minor commands
    ..registerCommand("info", infoCommand);

  Interactions(botInstance)
    ..registerSlashCommand(SlashCommandBuilder("info", "Info about bot state ", [])
      ..registerHandler(infoSlashCommand))
    ..registerSlashCommand(SlashCommandBuilder("tag", "Show and manipulate tags", [
      CommandOptionBuilder(CommandOptionType.subCommand, "show", "Shows tag to everyone", options: [CommandOptionBuilder(CommandOptionType.string, "name", "Name of tag to show", required: true)])
        ..registerHandler((event) => showTagHandler(event, ephemeral: false)),
      CommandOptionBuilder(CommandOptionType.subCommand, "preview", "Shows tag only for yourself", options: [CommandOptionBuilder(CommandOptionType.string, "name", "Name of tag to show", required: true)])
        ..registerHandler((event) => showTagHandler(event, ephemeral: true)),
      CommandOptionBuilder(CommandOptionType.subCommand, "create", "Creates new tag", options: [CommandOptionBuilder(CommandOptionType.string, "name", "Name of tag", required: true), CommandOptionBuilder(CommandOptionType.string, "content", "Content of the tag", required: true)])
        ..registerHandler(createTagHandler),
      CommandOptionBuilder(CommandOptionType.subCommand, "delete", "Deletes tag", options: [CommandOptionBuilder(CommandOptionType.string, "name", "Name of tag", required: true)])
        ..registerHandler(deleteTagHandler),
      CommandOptionBuilder(CommandOptionType.subCommand, "stats", "Tag stats", options: [])
        ..registerHandler(tagStatsHandler),
    ]))
    ..registerSlashCommand(SlashCommandBuilder("avatar", "Shows avatar of the user", [CommandOptionBuilder(CommandOptionType.user, "user", "User to display avatar")])
      ..registerHandler(avatarSlashHandler))
    ..registerSlashCommand(SlashCommandBuilder("ping", "Shows bots latency", [])
      ..registerHandler(pingSlashHandler))
    ..registerSlashCommand(SlashCommandBuilder("docs", "Documentation for nyxx", [
      CommandOptionBuilder(CommandOptionType.subCommand, "get", "Fetches docs for given phrase", options: [CommandOptionBuilder(CommandOptionType.string, "phrase", "Phrase to fetch from docs", required: true)])
        ..registerHandler(docsGetSlashHandler),
      CommandOptionBuilder(CommandOptionType.subCommand, "search", "Searches docs for wanted phrase", options: [CommandOptionBuilder(CommandOptionType.string, "phrase", "Phrase to fetch from docs", required: true)])
        ..registerHandler(docsSearchHandler),
      CommandOptionBuilder(CommandOptionType.subCommand, "links", "Returns links to docs")
        ..registerHandler(docsLinksHandler)
    ]))
    ..syncOnReady();
}

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

Future<void> avatarSlashHandler(SlashCommandInteractionEvent event) async {
  await event.acknowledge();

  final user = event.interaction.resolved?.users.first;
  if (user == null) {
    return event.respond(MessageBuilder.content("Invalid user specified"));
  }

  return event.respond(MessageBuilder.content(user.avatarURL(size: 512)), hidden: true);
}

Future<void> descriptionCommand(CommandContext ctx, String content) async {
  if(ctx.channel is TextGuildChannel) {
    await ctx.sendMessage(MessageBuilder.content((ctx.channel as TextGuildChannel).topic!));
    return;
  }

  await ctx.sendMessage(MessageBuilder.content("Invalid channel!"));
}

Future<void> pingSlashHandler(SlashCommandInteractionEvent event) async {
  final random = Random();
  final color = DiscordColor.fromRgb(random.nextInt(255), random.nextInt(255), random.nextInt(255));
  final gatewayDelayInMillis = botInstance.shardManager.shards.map((e) => e.gatewayLatency.inMilliseconds).reduce((value, element) => value + element) /~ botInstance.shards;

  final apiStopwatch = Stopwatch()..start();
  await http.head(Uri(scheme: "https", host: Constants.host, path: Constants.baseUri));
  final apiPing = apiStopwatch.elapsedMilliseconds;

  final stopwatch = Stopwatch()..start();

  final embed = EmbedBuilder()
    ..color = color
    ..addField(name: "Gateway latency", content: "$gatewayDelayInMillis ms", inline: true)
    ..addField(name: "REST latency", content: "$apiPing ms", inline: true)
    ..addField(name: "Message roundup time", content: "Pending...", inline: true);

  await event.respond(MessageBuilder.embed(embed));

  embed
    ..replaceField(name: "Message roundup time", content: "${stopwatch.elapsedMilliseconds} ms", inline: true);

  await event.editOriginalResponse(MessageBuilder.embed(embed));
}

/// Commented for now since I haven't decided yet if I want to keep such functionality
// Future<void> leaveChannelCommand(CommandContext ctx, String content) async {
//   final shard = ctx.client.shardManager.shards.firstWhere((element) => element.guilds.contains(ctx.guild!.id));
//
//   shard.changeVoiceState(ctx.guild!.id, null);
//   await ctx.sendMessage(MessageBuilder.content("Left channel!"));
// }
//
// Future<void> joinChannelCommand(CommandContext ctx, String content) async {
//   final shard = ctx.client.shardManager.shards.firstWhere((element) => element.guilds.contains(ctx.guild!.id));
//
//   shard.changeVoiceState(ctx.guild!.id, Snowflake(content.split(" ").last));
//   await ctx.sendMessage(MessageBuilder.content("Joined to channel!"));
// }
//
// Future<void> execCommand(CommandContext ctx, String content) async {
//   final stopwatch = Stopwatch()..start();
//
//   final text = ctx.message.content.replaceFirst("${utils.envPrefix}exec", "");
//   final output = await exec.eval(text);
//
//   final footer = EmbedFooterBuilder()..text = "Exec time: ${stopwatch.elapsedMilliseconds} ms";
//   final embed = EmbedBuilder()
//     ..title = "Output"
//     ..description = output
//     ..footer = footer;
//
//   await ctx.sendMessage(MessageBuilder.embed(embed));
// }

Future<void> docsGetSlashHandler(SlashCommandInteractionEvent event) async {
  await event.acknowledge();

  await event.respond(await docsGetMessageBuilder(event.args.firstWhere((element) => element.name == "phrase").value.toString()));
}

Future<void> docsGetCommand(CommandContext ctx, String content) async {
  await ctx.sendMessage(await docsGetMessageBuilder(content));
}

Future<MessageBuilder> docsGetMessageBuilder(String phrase) async {
  final searchString = phrase.split(" ").last.split("#|.");
  final docsDef = await docs.getDocDefinition(searchString.first, searchString.length > 1 ? searchString.last : null);

  if (docsDef == null) {
    return MessageBuilder.content("Cannot find docs for what you typed");
  }

  return MessageBuilder.embed(EmbedBuilder()
    ..addField(name: "Type", content: docsDef.type, inline: true)
    ..addField(name: "Name", content: docsDef.name, inline: true)
    ..description = "[${phrase.split(" ").last}](${docsDef.absoluteUrl})");
}

Future<MessageBuilder> docsLinksMessageBuilder() async => MessageBuilder.content(docs.basePath);

Future<void> docsLinksHandler(SlashCommandInteractionEvent event) async {
  await event.respond(await docsLinksMessageBuilder());
}

Future<void> docsCommand(CommandContext ctx, String content) async {
  await ctx.sendMessage(await docsLinksMessageBuilder());
}

Future<MessageBuilder> docsSearchMessageBuilder(String phrase) async {
  final query = phrase.split(" ").last;
  final results = docs.searchDocs(query);

  if(results.isEmpty) {
    return MessageBuilder.content("Nothing found matching: `$query`");
  }

  final buffer = StringBuffer();
  for (final def in results) {
    buffer.write("[${def.name}](${def.absoluteUrl})\n");
  }

  final embed = EmbedBuilder()
    ..description = buffer.toString();

  return MessageBuilder.embed(embed);
}

Future<void> docsSearchHandler(SlashCommandInteractionEvent event) async {
  await event.acknowledge();

  await event.respond(await docsSearchMessageBuilder(event.args.firstWhere((element) => element.name == "phrase").value.toString()));
}

Future<void> docsSearchCommand(CommandContext ctx, String content) async {
  await ctx.sendMessage(await docsSearchMessageBuilder(content));
}

Future<EmbedBuilder> infoGenericCommand(Nyxx client, [int shardId = 0]) async {
  final color = DiscordColor.fromRgb(
      Random().nextInt(255), Random().nextInt(255), Random().nextInt(255));

  return EmbedBuilder()
    ..addAuthor((author) {
      author.name = client.self.tag;
      author.iconUrl = client.self.avatarURL();
      author.url = "https://github.com/nyxx-discord/nyxx";
    })
    ..addFooter((footer) {
      footer.text = "Nyxx ${Constants.version} | Shard [${shardId + 1}] of [${client.shards}] | Dart SDK ${utils.dartVersion}";
    })
    ..color = color
    ..addField(name: "Cached guilds", content: client.guilds.count, inline: true)
    ..addField(name: "Cached users", content: client.users.count, inline: true)
    ..addField(
        name: "Cached channels",
        content: client.channels.count,
        inline: true
    )
    ..addField(
        name: "Cached voice states",
        content: client.guilds.values
            .map((g) => g.voiceStates.count)
            .reduce((f, s) => f + s),
        inline: true
    )
    ..addField(
        name: "Shard count",
        content: client.shards,
        inline: true
    )
    ..addField(
        name: "Cached messages",
        content: client.channels.find((item) => item is TextChannel).cast<TextChannel>().map((e) => e.messageCache.count).fold(0, (first, second) => (first as int) + second),
        inline: true
    )
    ..addField(
        name: "Memory usage (current/RSS)",
        content: utils.getMemoryUsageString(),
        inline: true
    )
    ..addField(
        name: "Member count (online/total)",
        content: utils.getApproxMemberCount(client),
        inline: true
    )
    ..addField(
        name: "Uptime",
        content: formatFull(client.startTime)
    )
    ..addField(
        name: "Last doc update",
        content: formatFull(await docs.fetchLastDocUpdate())
  );
}

Future<void> infoSlashCommand(InteractionEvent event) async {
  await event.acknowledge();

  await event.respond(MessageBuilder.embed(await infoGenericCommand(botInstance)));
}

Future<void> infoCommand(CommandContext ctx, String content) async {
  await ctx.reply(MessageBuilder.embed(await infoGenericCommand(ctx.client, ctx.shardId)));
}
