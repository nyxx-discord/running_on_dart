import "dart:math" show Random;

import "package:nyxx/nyxx.dart";
import 'package:nyxx_interactions/nyxx_interactions.dart';
import "package:running_on_dart/src/internal/utils.dart" show dartVersion, getMemoryUsageString;
import "package:running_on_dart/src/modules/docs.dart" show fetchLastDocUpdate, lastDocCacheUpdate;
import "package:time_ago_provider/time_ago_provider.dart" show formatFull;

Future<ComponentMessageBuilder> infoGenericCommand(INyxxWebsocket client, [int shardId = 0]) async {
  final color = DiscordColor.fromRgb(Random().nextInt(255), Random().nextInt(255), Random().nextInt(255));

  final embed = EmbedBuilder()
    ..addAuthor((author) {
      author.name = client.self.tag;
      author.iconUrl = client.self.avatarURL();
      author.url = "https://github.com/nyxx-discord/nyxx";
    })
    ..addFooter((footer) {
      footer.text = "Nyxx ${Constants.version} | Shard [${shardId + 1}] of [${client.shards}] | Dart SDK $dartVersion";
    })
    ..color = color
    ..addField(name: "Cached guilds", content: client.guilds.length, inline: true)
    ..addField(name: "Cached users", content: client.users.length, inline: true)
    ..addField(name: "Cached channels", content: client.channels.length, inline: true)
    ..addField(name: "Cached voice states", content: client.guilds.values.map((g) => g.voiceStates.length).reduce((f, s) => f + s), inline: true)
    ..addField(name: "Shard count", content: client.shards, inline: true)
    ..addField(
        name: "Cached messages",
        content: client.channels.values.whereType<ITextChannel>().map((e) => e.messageCache.length).fold(0, (first, second) => (first as int) + second),
        inline: true)
    ..addField(name: "Memory usage (current/RSS)", content: getMemoryUsageString(), inline: true)
    ..addField(name: "Uptime", content: formatFull(client.startTime))
    ..addField(name: "Last doc update", content: formatFull(await fetchLastDocUpdate()))
    ..addField(name: "Last local docs index update", content: formatFull(lastDocCacheUpdate));

  return ComponentMessageBuilder()
    ..embeds = [embed]
    ..componentRows = [
      [LinkButtonBuilder("Add running on dart to your guild", client.app.getInviteUrl())]
    ];
}
