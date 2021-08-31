import 'dart:async';

import "package:nyxx/nyxx.dart";
import 'package:nyxx_commander/commander.dart';

const allowedVoiceCommandSnowflakes = [
  302359032612651009,
  281314080923320321,
  612653298532745217
];

FutureOr<bool> adminBeforehandler(CommandContext context) =>
    allowedVoiceCommandSnowflakes.contains(context.author.id.id);

Future<void> leaveChannel(Snowflake guildId, Nyxx client) async {
  final shard = client.shardManager.shards.firstWhere((element) => element.guilds.contains(guildId));

  shard.changeVoiceState(guildId, null);
}

Future<void> joinChannel(Snowflake guildId, Snowflake channelId, Nyxx client) async {
  final shard = client.shardManager.shards.firstWhere((element) => element.guilds.contains(guildId));

  shard.changeVoiceState(guildId, channelId);
}
