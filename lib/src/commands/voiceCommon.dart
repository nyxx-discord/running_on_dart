import "dart:async";

import "package:nyxx/nyxx.dart";
import "package:nyxx_commander/commander.dart";
import "package:running_on_dart/src/modules/settings/settings.dart";

FutureOr<bool> adminBeforehandler(CommandContext context) =>
    privilegedAdminSnowflakes.contains(context.author.id.id);

Future<void> leaveChannel(Snowflake guildId, Nyxx client) async {
  final shard = client.shardManager.shards.firstWhere((element) => element.guilds.contains(guildId));

  shard.changeVoiceState(guildId, null);
}

Future<void> joinChannel(Snowflake guildId, Snowflake channelId, Nyxx client) async {
  final shard = client.shardManager.shards.firstWhere((element) => element.guilds.contains(guildId));

  shard.changeVoiceState(guildId, channelId);
}
