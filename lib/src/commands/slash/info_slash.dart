import "dart:math" show Random;

import "package:http/http.dart" as http;

import "package:nyxx/nyxx.dart";
import "package:nyxx_interactions/nyxx_interactions.dart";
import "package:running_on_dart/src/commands/info_common.dart" show infoGenericCommand;

Future<void> infoSlashCommand(ISlashCommandInteractionEvent event) async {
  await event.acknowledge();

  await event.respond(await infoGenericCommand(event.client as INyxxWebsocket));
}

Future<void> pingSlashHandler(ISlashCommandInteractionEvent event) async {
  final random = Random();
  final color = DiscordColor.fromRgb(random.nextInt(255), random.nextInt(255), random.nextInt(255));
  final gatewayDelayInMillis =
      (event.client as INyxxWebsocket).shardManager.shards.map((e) => e.gatewayLatency.inMilliseconds).reduce((value, element) => value + element) /
          ~(event.client as INyxxWebsocket).shards;

  final apiStopwatch = Stopwatch()..start();
  await http.head(Uri(scheme: "https", host: Constants.host, path: Constants.baseUri));
  final apiPing = apiStopwatch.elapsedMilliseconds;

  final stopwatch = Stopwatch()..start();

  final embed = EmbedBuilder()
    ..color = color
    ..addField(name: "Gateway latency", content: "${gatewayDelayInMillis.abs()} ms", inline: true)
    ..addField(name: "REST latency", content: "$apiPing ms", inline: true)
    ..addField(name: "Message roundup time", content: "Pending...", inline: true);

  await event.respond(MessageBuilder.embed(embed));

  embed.replaceField(name: "Message roundup time", content: "${stopwatch.elapsedMilliseconds} ms", inline: true);

  await event.editOriginalResponse(MessageBuilder.embed(embed));
}

Future<void> avatarSlashHandler(ISlashCommandInteractionEvent event) async {
  await event.acknowledge();

  final user = event.interaction.resolved?.users.first;
  if (user == null) {
    return event.respond(MessageBuilder.content("Invalid user specified"));
  }

  return event.respond(MessageBuilder.content(user.avatarURL(size: 512)), hidden: true);
}
