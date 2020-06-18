/*
Configuration via environment variables:
  ROD_PREFIX - prefix that bot will use for commands
  DISCORD_TOKEN - bot token to login
  ROD_ADMIN_ID - id of admin
*/

import "dart:io";
import "dart:math";

import "package:logging/logging.dart";
import "package:nyxx/nyxx.dart";
import "package:nyxx.commander/commander.dart";
import "package:time_ago_provider/time_ago_provider.dart" as time_ago;

import "docs.dart" as docs;
import "exec.dart" as exec;
import "utils.dart" as utils;

final Logger logger = Logger("Bot");
final prefix = Platform.environment["ROD_PREFIX"];

main(List<String> arguments) async {
  setupDefaultLogging();
  final bot = Nyxx(Platform.environment["DISCORD_TOKEN"]!, options: ClientOptions(guildSubscriptions: false));
  Commander(bot, prefix: prefix)
    ..registerCommandGroup(CommandGroup(beforeHandler: checkForAdmin)
      ..registerSubCommand("leave", leaveChannelCommand)
      ..registerSubCommand("join", joinChannelCommand)
      ..registerSubCommand("exec", execCommand, beforeHandler: checkForLusha))
    ..registerCommandGroup(CommandGroup(name: "docs")
      ..registerSubCommand("get", docsCommand)
      ..registerSubCommand("search", docsSearchCommand))
    ..registerCommand("info", infoCommand)
    ..registerCommand("ping", pingCommand)
    ..registerCommand("help", helpCommand)
    ..registerCommand("description", descriptionCommand)
    ..registerCommand("avatar", userAvatarCommand);
}

Future<void> helpCommand(CommandContext ctx, String content) async {
  final helpString = "‎\n"
      "**${prefix}join** *<channel_id>* - join specified channel. \n"
      "**${prefix}leave ** - leaves channel. \n"
      "**${prefix}exec ** *<string_to_execute>* - executes Dart code. \n"
      "**${prefix}docs get ** *<ClassName[#memberName]>* - Sends url to nyxx docs for specified entry. \n"
      "**${prefix}docs search ** *<query>* - Searches docs for *query* \n"
      "**${prefix}info ** - sends basic info about bot. \n"
      "**${prefix}ping ** - sends current bot latency. \n"
      "**${prefix}help ** - this command. \n"
      "**${prefix}description ** - sends current channel description. \n"
      "**${prefix}avatar ** - Replies with mentioned user avatar. \n";

  await ctx.reply(content: helpString);
}

Future<void> userAvatarCommand(CommandContext ctx, String content) async {
  String? avatarUrl;

  if(ctx.message.mentions.isEmpty) {
    avatarUrl = ctx.author?.avatarURL(size: 1024);
  } else {
    avatarUrl = ctx.message.mentions.first.avatarURL(size: 1024);
  }

  if(avatarUrl == null) {
    await ctx.reply(content: "Cannot obtain avatar url.");
    return;
  }

  await ctx.reply(content: avatarUrl);
}

Future<void> descriptionCommand(CommandContext ctx, String content) async {
  if(ctx.channel is CachelessTextChannel) {
    await ctx.reply(content: (ctx.channel as CachelessTextChannel).topic);
    return;
  }

  await ctx.reply(content: "Invalid channel!");
}

Future<void> pingCommand(CommandContext ctx, String content) async {
  final gatewayDelayInMilis = ctx.client.shardManager.shards.firstWhere((element) => element.id == ctx.shardId).gatewayLatency.inMilliseconds;
  final stopwatch = Stopwatch()..start();

  final messageContent = "‎\n"
      "**Gateway latency:** $gatewayDelayInMilis ms \n"
      "**Message roundup time:** ";
  final message = await ctx.reply(content: "$messageContent *Pending*");
  await message.edit(content: "$messageContent ${stopwatch.elapsedMilliseconds} ms");
}

Future<void> leaveChannelCommand(CommandContext ctx, String content) async {
  final guildId = (ctx.message.channel as CachelessGuildChannel).guildId;
  final shard = ctx.client.shardManager.shards.firstWhere((element) => element.guilds.contains(guildId));

  shard.changeVoiceState(guildId, null);
  await ctx.reply(content: "Channel left!");
}

Future<void> joinChannelCommand(CommandContext ctx, String content) async {
  final guildId = (ctx.message.channel as CachelessGuildChannel).guildId;
  final shard = ctx.client.shardManager.shards.firstWhere((element) => element.guilds.contains(guildId));

  shard.changeVoiceState(guildId, Snowflake(content.split(" ").last));
  await ctx.reply(content: "Channel joined!");
}

Future<void> execCommand(CommandContext ctx, String content) async {
  final stopwatch = Stopwatch()..start();

  final text = ctx.message.content.replaceFirst("${prefix}exec", "");
  final output = await exec.eval(text);

  final footer = EmbedFooterBuilder()..text = "Exec time: ${stopwatch.elapsedMilliseconds} ms";
  final embed = EmbedBuilder()
    ..title = "Output"
    ..description = output
    ..footer = footer;

  await ctx.reply(embed: embed);
}

Future<void> docsCommand(CommandContext ctx, String content) async {
  final searchString = content.split(" ").last.split("#");
  final docsUrl = await docs.getUrlToProperty(searchString.first, searchString.length > 1 ? searchString.last : null);

  final embed = EmbedBuilder()
    ..description = "[${content.split(" ").last}]($docsUrl)";

  await ctx.reply(embed: embed);
}

Future<void> docsSearchCommand(CommandContext ctx, String content) async {
  final query = content.split(" ").last;

  final buffer = StringBuffer();
  (await docs.searchDocs(query)).forEach((key, value) => buffer.write("[$key]($value)\n"));

  if(buffer.isEmpty) {
    await ctx.reply(content: "Nothing found matching: `$query`");
    return;
  }

  final embed = EmbedBuilder()
    ..description = buffer.toString();

  await ctx.reply(embed: embed);
}

Future<void> infoCommand(CommandContext ctx, String content) async {
  final color = DiscordColor.fromRgb(
      Random().nextInt(255), Random().nextInt(255), Random().nextInt(255));

  final embed = EmbedBuilder()
    ..addAuthor((author) {
      author.name = ctx.client.self.tag;
      author.iconUrl = ctx.client.self.avatarURL();
      author.url = "https://github.com/l7ssha/nyxx";
    })
    ..addFooter((footer) {
      footer.text = "Nyxx 1.0.0 | Shard [${ctx.shardId + 1}] of [${ctx.client.shards}] | ${utils.dartVersion}";
    })
    ..color = color
    ..addField(
        name: "Uptime",
        content: time_ago.format(ctx.client.startTime, locale: "en_short"),
        inline: true)
    ..addField(
        name: "DartVM memory usage",
        content: "${(ProcessInfo.currentRss / 1024 / 1024).toStringAsFixed(2)} MB",
        inline: true)
    ..addField(name: "Created at", content: ctx.client.app.createdAt, inline: true)
    ..addField(name: "Guild count", content: ctx.client.guilds.count, inline: true)
    ..addField(name: "Users count", content: ctx.client.users.count, inline: true)
    ..addField(
        name: "Channels count",
        content: ctx.client.channels.count,
        inline: true)
    ..addField(
        name: "Users in voice",
        content: ctx.client.guilds.values
            .map((g) => g.voiceStates.count)
            .reduce((f, s) => f + s),
        inline: true)
    ..addField(name: "Shard count", content: ctx.client.shards, inline: true)
    ..addField(name: "Cached messages", content: ctx.client.channels.find((item) => item is MessageChannel).cast<MessageChannel>().map((e) => e.messages.count).fold(0, (first, second) => (first as int) + second), inline: true);

  await ctx.reply(embed: embed);
}

/*
Future<void> tagDeleteCommand(CommandContext ctx, String content) async {
  await tags.deleteTag(ctx.getArguments().last);

  await ctx.reply(content: "Tag has been deleted");
}

Future<void> tagUpdateCommand(CommandContext ctx, String content) async {
  final arguments = ctx.getArguments();

  final tagName = arguments.first;
  final tagContent = arguments.last;

  await tags.updateTag(tagName, tagContent);

  await ctx.reply(content: "Tag `$tagName` has been updated!");
}

Future<void> tagCommand(CommandContext ctx, String content) async {
  final tagName = ctx.getArguments().join(" ");
  final tagContent = await tags.getTag(tagName);

  if(tagContent == null) {
    return ctx.reply(content: "No such tag");
  }

  await ctx.reply(content: tagContent);
}

Future<void> tagNewCommand(CommandContext ctx, String content) async {
  final arguments = ctx.getArguments();

  final tagName = arguments.first;
  final tagContent = arguments.last;

  await tags.insertTag(tagName, tagContent);

  await ctx.reply(content: "Tag `$tagName` created!");
}
*/

Future<bool> checkForLusha(CommandContext context) async =>
    context.author!.id == 302359032612651009;

Future<bool> checkForAdmin(CommandContext context) async {
  if(Platform.environment["ROD_ADMIN_ID"] != null) {
    return context.author!.id == Platform.environment["ROD_ADMIN_ID"];
  }

  return checkForLusha(context);
}
