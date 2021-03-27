/*
Configuration via utils.environment variables:
  ROD_PREFIX - prefix that bot will use for commands
  ROD_TOKEN - bot token to login
  ROD_ADMIN_ID - id of admin
*/

import "dart:convert" show jsonDecode;
import "dart:io" show Process, pid;
import "dart:math" show Random;

import "package:http/http.dart" as http;
import "package:nyxx/nyxx.dart" show ClientOptions, Constants, DiscordColor, EmbedBuilder, EmbedFooterBuilder, GatewayIntents, Nyxx, Snowflake, TextChannel, TextGuildChannel;
import "package:nyxx_commander/commander.dart" show CommandContext, CommandGroup, Commander;
import "package:time_ago_provider/time_ago_provider.dart" show formatFull;

import "docs.dart" as docs;
import "exec.dart" as exec;
import "utils.dart" as utils;

void main(List<String> arguments) async {
  final bot = Nyxx(utils.envToken!, GatewayIntents.allUnprivileged, options: ClientOptions(guildSubscriptions: false));
  Commander(bot, prefix: utils.envPrefix)
    // Admin stuff
    ..registerCommandGroup(CommandGroup(beforeHandler: utils.checkForAdmin)
      ..registerSubCommand("leave", leaveChannelCommand)
      ..registerSubCommand("join", joinChannelCommand)
      ..registerSubCommand("exec", execCommand)
      ..registerSubCommand("shutdown", shutdownCommand)
      ..registerSubCommand("selfNick", selfNickCommand))
    // Docs commands
    ..registerCommandGroup(CommandGroup(name: "docs")
      ..registerDefaultCommand(docsCommand)
      ..registerSubCommand("get", docsGetCommand)
      ..registerSubCommand("search", docsSearchCommand))
    // Minor commands
    ..registerCommand("info", infoCommand)
    ..registerCommand("ping", pingCommand)
    ..registerCommand("help", helpCommand)
    ..registerCommand("description", descriptionCommand)
    ..registerCommand("avatar", userAvatarCommand)
    // Qr code stuff
    ..registerCommandGroup(CommandGroup(name: "qr")
      ..registerSubCommand("gen", genQrCodeCommand)
      ..registerSubCommand("read", readQrCodeCommand));
}

Future<void> helpCommand(CommandContext ctx, String content) async {
  // Assign method to variable for shorter name
  const helpGen = utils.helpCommandGen;

  // Write zero-width character to skip first line where nick is
  final buffer = StringBuffer("‎\n");

  buffer.write(helpGen("join", "join specified channel", additionalInfo: "<channel_id>"));
  buffer.write(helpGen("leave", "leaves channel"));
  buffer.write(helpGen("exec", "executes Dart code", additionalInfo: "<string_to_execute>"));
  buffer.write(helpGen("docs", "Sends link to nyxx docs"));
  buffer.write(helpGen("docs get", "Sends url to nyxx docs for specified entry", additionalInfo: "<ClassName[#memberName]>"));
  buffer.write(helpGen("docs search", "Searches docs for *query*", additionalInfo: "<query>"));
  buffer.write(helpGen("info", "sends basic info about bot"));
  buffer.write(helpGen("ping", "sends current bot latency"));
  buffer.write(helpGen("help", "this command"));
  buffer.write(helpGen("description", "sends current channel description"));
  buffer.write(helpGen("avatar", "Replies with mentioned user avatar"));
  buffer.write(helpGen("qr gen ", "Generates qr code with provided data", additionalInfo: "<data>"));
  buffer.write(helpGen("qr read", "Reads qr code from uploaded image in same message as command"));
  buffer.write(helpGen("selfNick", "Sets nick of bot"));
  buffer.write(helpGen("shutdown", "Shuts down bot"));

  await ctx.sendMessage(content: buffer.toString());
}

Future<void> selfNickCommand(CommandContext ctx, String content) async {
  if (ctx.guild == null) {
    await ctx.sendMessage(content: "Cannot change nick in DMs");
    return;
  }

  await ctx.guild?.changeSelfNick(ctx.getArguments().first);
}

Future<void> shutdownCommand(CommandContext ctx, String content) async {
  Process.killPid(pid);
}

Future<void> readQrCodeCommand(CommandContext ctx, String content) async {
  if(ctx.message.attachments.isEmpty) {
    await ctx.sendMessage(content: "Invalid usage. Upload image alongside with command!");
    return;
  }

  final url = Uri.https("api.qrserver.com", "v1/read-qr-code/", {
    "fileurl" : ctx.message.attachments.first.url
  });

  final result = jsonDecode(await http.read(url));

  if(result.first["symbol"].first["error"] != null) {
    await ctx.sendMessage(content: "Error: `${result.first["symbol"]["error"]}`");
    return;
  }

  await ctx.sendMessage(embed:
    EmbedBuilder()
      ..description = result.first["symbol"].first["data"].toString()
  );
}

Future<void> genQrCodeCommand(CommandContext ctx, String content) async {
  final args = ctx.getArguments().toList().join(" ");

  if(args.isEmpty) {
    await ctx.sendMessage(content: "Specify text for qr code.");
    return;
  }

  final queryParams = <String, String> {
    "data": args
  };

  final url = Uri.https("api.qrserver.com", "v1/create-qr-code/", queryParams);

  await ctx.sendMessage(content: url.toString());
}

Future<void> userAvatarCommand(CommandContext ctx, String content) async {
  String? avatarUrl;

  if(ctx.message.mentions.isEmpty) {
    avatarUrl = ctx.author.avatarURL(size: 1024);
  } else {
    try {
      avatarUrl = (await ctx.message.mentions.first.getOrDownload()).avatarURL(size: 1024);
    } on Exception {
      avatarUrl = null;
    }
  }

  if(avatarUrl == null) {
    await ctx.sendMessage(content: "Cannot obtain avatar url.");
    return;
  }

  await ctx.sendMessage(content: avatarUrl);
}

Future<void> descriptionCommand(CommandContext ctx, String content) async {
  if(ctx.channel is TextGuildChannel) {
    await ctx.sendMessage(content: (ctx.channel as TextGuildChannel).topic);
    return;
  }

  await ctx.sendMessage(content: "Invalid channel!");
}

Future<void> pingCommand(CommandContext ctx, String content) async {
  final random = Random();
  final color = DiscordColor.fromRgb(random.nextInt(255), random.nextInt(255), random.nextInt(255));
  final gatewayDelayInMillis = ctx.client.shardManager.shards.firstWhere((element) => element.id == ctx.shardId).gatewayLatency.inMilliseconds;

  final apiStopwatch = Stopwatch()..start();
  await http.head(Uri(scheme: "https", host: Constants.host, path: Constants.baseUri));
  final apiPing = apiStopwatch.elapsedMilliseconds;

  final stopwatch = Stopwatch()..start();

  final embed = EmbedBuilder()
    ..color = color
    ..addField(name: "Gateway latency", content: "$gatewayDelayInMillis ms", inline: true)
    ..addField(name: "REST latency", content: "$apiPing ms", inline: true)
    ..addField(name: "Message roundup time", content: "Pending...", inline: true);

  final message = await ctx.sendMessage(embed: embed);

  embed
    ..replaceField(name: "Message roundup time", content: "${stopwatch.elapsedMilliseconds} ms", inline: true);

  await message.edit(embed: embed);
}

Future<void> leaveChannelCommand(CommandContext ctx, String content) async {
  final shard = ctx.client.shardManager.shards.firstWhere((element) => element.guilds.contains(ctx.guild!.id));

  shard.changeVoiceState(ctx.guild!.id, null);
  await ctx.sendMessage(content: "Left channel!");
}

Future<void> joinChannelCommand(CommandContext ctx, String content) async {
  final shard = ctx.client.shardManager.shards.firstWhere((element) => element.guilds.contains(ctx.guild!.id));

  shard.changeVoiceState(ctx.guild!.id, Snowflake(content.split(" ").last));
  await ctx.sendMessage(content: "Joined to channel!");
}

Future<void> execCommand(CommandContext ctx, String content) async {
  final stopwatch = Stopwatch()..start();

  final text = ctx.message.content.replaceFirst("${utils.envPrefix}exec", "");
  final output = await exec.eval(text);

  final footer = EmbedFooterBuilder()..text = "Exec time: ${stopwatch.elapsedMilliseconds} ms";
  final embed = EmbedBuilder()
    ..title = "Output"
    ..description = output
    ..footer = footer;

  await ctx.sendMessage(embed: embed);
}

Future<void> docsCommand(CommandContext ctx, String content) async {
  await ctx.sendMessage(content: docs.basePath);
}

Future<void> docsGetCommand(CommandContext ctx, String content) async {
  final searchString = content.split(" ").last.split("#|.");
  final docsDef = await docs.getDocDefinition(searchString.first, searchString.length > 1 ? searchString.last : null);

  if (docsDef == null) {
    await ctx.sendMessage(content: "Cannot find docs for what you typed");
    return;
  }

  final embed = EmbedBuilder()
    ..addField(name: "Type", content: docsDef.type, inline: true)
    ..addField(name: "Name", content: docsDef.name, inline: true)
    ..description = "[${content.split(" ").last}](${docsDef.absoluteUrl})";

  await ctx.sendMessage(embed: embed);
}

Future<void> docsSearchCommand(CommandContext ctx, String content) async {
  final query = content.split(" ").last;
  final results = docs.searchDocs(query);

  if(results.isEmpty) {
    await ctx.sendMessage(content: "Nothing found matching: `$query`");
    return;
  }

  final buffer = StringBuffer();
  for (final def in results) {
    buffer.write("[${def.name}](${def.absoluteUrl})\n");
  }

  final embed = EmbedBuilder()
    ..description = buffer.toString();

  await ctx.sendMessage(embed: embed);
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
      footer.text = "Nyxx ${Constants.version} | Shard [${ctx.shardId + 1}] of [${ctx.client.shards}] | ${utils.dartVersion}";
    })
    ..color = color
    ..addField(name: "Cached guilds", content: ctx.client.guilds.count, inline: true)
    ..addField(name: "Cached users", content: ctx.client.users.count, inline: true)
    ..addField(
        name: "Cached channels",
        content: ctx.client.channels.count,
        inline: true)
    ..addField(
        name: "Cached voice states",
        content: ctx.client.guilds.values
            .map((g) => g.voiceStates.count)
            .reduce((f, s) => f + s),
        inline: true)
    ..addField(name: "Shard count", content: ctx.client.shards, inline: true)
    ..addField(name: "Cached messages", content: ctx.client.channels.find((item) => item is TextChannel).cast<TextChannel>().map((e) => e.messageCache.count).fold(0, (first, second) => (first as int) + second), inline: true)
    ..addField(
        name: "Memory usage (current/RSS)",
        content: utils.getMemoryUsageString(),
        inline: true
    )
    ..addField(name: "Approx member count", content: utils.getApproxMemberCount(ctx), inline: true)
    ..addField(
        name: "Uptime",
        content: formatFull(ctx.client.startTime))
    ..addField(name: "Created at", content: formatFull(ctx.client.app.createdAt));

  await ctx.sendMessage(embed: embed);
}
