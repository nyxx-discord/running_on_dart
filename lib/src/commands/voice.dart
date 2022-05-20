import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/checks.dart';

ChatGroup voice = ChatGroup(
  'voice',
  "Control the bot's voice channel",
  checks: [
    administratorCheck,
    GuildCheck.all(),
  ],
  children: [
    ChatCommand(
      'leave',
      'Leave the channel the bot is currently connected to',
      id('voice-leave', (IChatContext context) async {
        (context.client as INyxxWebsocket)
            .shardManager
            .shards
            .singleWhere((shard) => shard.guilds.contains(context.guild!.id))
            .changeVoiceState(context.guild!.id, null);

        await context.respond(MessageBuilder.content('Left voice channel!'));
      }),
    ),
    ChatCommand(
      'join',
      'Make the bot join a voice channel',
      id('voice-join', (
        IChatContext context, [
        @Description('The channel to join') IVoiceGuildChannel? channel,
      ]) async {
        channel ??= await context.member?.voiceState?.channel?.getOrDownload() as IVoiceGuildChannel?;

        if (channel == null) {
          await context.respond(MessageBuilder.content("Couldn't find a channel to join!"));
          return;
        }

        (context.client as INyxxWebsocket)
            .shardManager
            .shards
            .singleWhere((shard) => shard.guilds.contains(context.guild!.id))
            .changeVoiceState(context.guild!.id, channel.id);

        await context.respond(MessageBuilder.content('Joined voice channel!'));
      }),
    ),
  ],
);
