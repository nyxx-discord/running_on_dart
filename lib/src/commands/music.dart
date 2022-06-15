import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/checks.dart';
import 'package:running_on_dart/src/services/music.dart';

ChatGroup music = ChatGroup(
  'music',
  'Music related commands',
  checks: [
    GuildCheck.all(),
    sameVoiceChannelOrDisconnectedCheck,
  ],
  children: [
    ChatCommand(
      'play',
      'Plays music based on the given query',
      id('music-play', (
          IChatContext context,
          @Description('The name/url of the song/playlist to play') String query
        ) async {
        final node = MusicService.instance.cluster.getOrCreatePlayerNode(context.guild!.id);
        connectIfNeeded(context);
        final result = await node.autoSearch(query);

        if (result.tracks.isEmpty) {
          await respond(context, MessageBuilder.content('No results were found'));
          return;
        }

        if (result.playlistInfo.name != null) {
          for (final track in result.tracks) {
            node.play(
              context.guild!.id,
              track,
              requester: context.member!.id,
              channelId: context.channel.id
            ).queue();
          }

          await respond(context, MessageBuilder.content(
              'Playlist `${result.playlistInfo.name}`($query) enqueued'
          ));

        } else {
          node.play(
            context.guild!.id,
            result.tracks[0],
            requester: context.member!.id,
            channelId: context.channel.id
          ).queue();
          await respond(context, MessageBuilder.content(
              'Track `${result.tracks[0].info?.title}` enqueued'
          ));
        }
      })
    ),
    ChatCommand(
      'skip',
      'Skips the currently playing track',
      checks: [connectedToAVoiceChannelCheck],
      id('music-skip', (IChatContext context) async {
        final node = MusicService.instance.cluster.getOrCreatePlayerNode(context.guild!.id);
        final player = node.players[context.guild!.id]!;

        if (player.queue.isEmpty) {
          await respond(context, MessageBuilder.content('The queue is clear!'));
          return;
        }

        node.skip(context.guild!.id);
        await respond(context, MessageBuilder.content('Skipped current track'));
      })
    ),
    ChatCommand(
      'stop',
      'Stops the current player and clears its track queue',
      checks: [connectedToAVoiceChannelCheck],
      id('music-stop', (IChatContext context) async {
        final node = MusicService.instance.cluster.getOrCreatePlayerNode(context.guild!.id);
        node.stop(context.guild!.id);
        await respond(context, MessageBuilder.content('Player stopped!'));
      })
    ),
    ChatCommand(
      'leave',
      'Leaves the current voice channel',
      checks: [connectedToAVoiceChannelCheck],
      id('music-leave', (IChatContext context) async {
        (context.client as INyxxWebsocket)
            .shardManager
            .shards
            .singleWhere((shard) => shard.guilds.contains(context.guild!.id))
            .changeVoiceState(context.guild!.id, null);
        await respond(context, MessageBuilder.content('Channel left'));
      })
    ),
    ChatCommand(
      'join',
      'Joins the voice channel you are in',
      checks: [notConnectedToAVoiceChannelCheck],
      id('music-join', (IChatContext context) async {
        MusicService.instance.cluster.getOrCreatePlayerNode(context.guild!.id);
        await connectIfNeeded(context);
        await respond(context, MessageBuilder.content('Joined your voice channel'));
      })
    ),
    ChatCommand(
      'volume',
      'Sets the volume for the player',
      checks: [connectedToAVoiceChannelCheck],
      id('music-volume', (
          IChatContext context,
          @Description('The new volume, this value must be contained between 0 and 1000') @UseConverter(IntConverter(min: 0, max: 1000)) int volume
        ) async {
        final node = MusicService.instance.cluster.getOrCreatePlayerNode(context.guild!.id);
        node.volume(context.guild!.id, volume);
        await respond(context, MessageBuilder.content('Volume changed to $volume'));
      })
    ),
    ChatCommand(
      'pause',
      'Pauses the player',
      id('music-pause', (IChatContext context) async {
        final node = MusicService.instance.cluster.getOrCreatePlayerNode(context.guild!.id);
        node.pause(context.guild!.id);
        await respond(context, MessageBuilder.content('Player paused'));
      })
    ),
    ChatCommand(
      'resume',
      'Resumes the currently playing track',
      id('music-resume', (IChatContext context) async {
        final node = MusicService.instance.cluster.getOrCreatePlayerNode(context.guild!.id);
        node.resume(context.guild!.id);
        await respond(context, MessageBuilder.content('Player resumed'));
      })
    )
  ]
);

Future<void> connectIfNeeded(IChatContext context) async {
  final selfMember = await context.guild!.selfMember.getOrDownload();

  if (
    (selfMember.voiceState == null || selfMember.voiceState!.channel == null) &&
    (context.member!.voiceState != null && context.member!.voiceState!.channel != null)
  ) {
    (context.client as INyxxWebsocket)
        .shardManager
        .shards
        .singleWhere((shard) => shard.guilds.contains(context.guild!.id))
        .changeVoiceState(context.guild!.id, context.member!.voiceState!.channel!.id);
  }
}

Future<void> respond(IChatContext context, MessageBuilder builder) async {
  if (context is InteractionChatContext) {
    await context.interactionEvent.editOriginalResponse(builder);
  } else {
    await context.respond(builder);
  }
}
