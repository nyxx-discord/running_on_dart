import "dart:async" show Future, FutureOr;

import "package:nyxx/nyxx.dart" show Nyxx, Snowflake;
import "package:nyxx_commander/commander.dart" show CommandContext;
import "package:running_on_dart/src/modules/settings/settings.dart" show privilegedAdminSnowflakes;

FutureOr<bool> adminBeforehandler(CommandContext context) => privilegedAdminSnowflakes.contains(context.author.id.id);

Future<void> leaveChannel(Snowflake guildId, Nyxx client) async {
  final shard = client.shardManager.shards.firstWhere((element) => element.guilds.contains(guildId));

  shard.changeVoiceState(guildId, null);
}

Future<void> joinChannel(Snowflake guildId, Snowflake channelId, Nyxx client) async {
  final shard = client.shardManager.shards.firstWhere((element) => element.guilds.contains(guildId));

  shard.changeVoiceState(guildId, channelId);
}
