import "dart:async" show Future, FutureOr;

import "package:nyxx/nyxx.dart";
import "package:nyxx_commander/nyxx_commander.dart";
import "package:running_on_dart/src/modules/settings/settings.dart" show privilegedAdminSnowflakes;

FutureOr<bool> adminBeforeHandler(ICommandContext context) => privilegedAdminSnowflakes.contains(context.author.id.id);

Future<void> leaveChannel(Snowflake guildId, INyxxWebsocket client) async {
  final shard = client.shardManager.shards.firstWhere((element) => element.guilds.contains(guildId));

  shard.changeVoiceState(guildId, null);
}

Future<void> joinChannel(Snowflake guildId, Snowflake channelId, INyxxWebsocket client) async {
  final shard = client.shardManager.shards.firstWhere((element) => element.guilds.contains(guildId));

  shard.changeVoiceState(guildId, channelId);
}
