import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/checks.dart';
import 'package:running_on_dart/src/models/jellyfin_config.dart';
import 'package:running_on_dart/src/modules/jellyfin.dart';
import 'package:tentacle/tentacle.dart';

Duration parseDurationFromTicks(int ticks) => Duration(microseconds: ticks ~/ 10);

extension DurationFromTicks on Duration {
  String formatShort() => toString().split('.').first.padLeft(8, "0");
}

String formatProgress(int currentPositionTicks, int totalTicks) {
  final progressPercentage = currentPositionTicks / totalTicks * 100;

  final currentPositionDuration = parseDurationFromTicks(currentPositionTicks);
  final totalDuration = parseDurationFromTicks(totalTicks);

  return "${currentPositionDuration.formatShort()}/${totalDuration.formatShort()} (${progressPercentage.toStringAsFixed(2)}%)";
}

Iterable<EmbedFieldBuilder> getMediaInfoEmbedFields(Iterable<MediaStream> mediaStreams) sync* {
  for (final mediaStream in mediaStreams) {
    final bitrate = ((mediaStream.bitRate ?? 0) / 1024 / 1024).toStringAsFixed(2);
    final trackTitle = mediaStream.title ?? mediaStream.displayTitle;

    yield EmbedFieldBuilder(
        name: "Media Info (${mediaStream.type!.name})", value: "$trackTitle ($bitrate Mbps)", isInline: true);
  }
}

EmbedFieldBuilder getExternalUrlsEmbedField(Iterable<ExternalUrl> externalUrls) {
  final fieldValue = externalUrls.map((externalUrl) => '[${externalUrl.name}](${externalUrl.url})').join(' ');

  return EmbedFieldBuilder(name: "External Urls", value: fieldValue.toString(), isInline: false);
}

EmbedBuilder? buildSessionEmbed(SessionInfo sessionInfo, JellyfinClientWrapper client) {
  final nowPlayingItem = sessionInfo.nowPlayingItem;
  if (nowPlayingItem == null) {
    return null;
  }

  final progress = formatProgress(sessionInfo.playState!.positionTicks ?? 1, nowPlayingItem.runTimeTicks ?? 1);

  final premiereDateString = nowPlayingItem.premiereDate!.format(TimestampStyle.shortDateTime);
  final userString = '${sessionInfo.userName} on ${sessionInfo.deviceName}';

  final primaryMediaStreams = (nowPlayingItem.mediaStreams as Iterable<MediaStream>? ?? [])
      .where((mediaStream) => [MediaStreamType.audio, MediaStreamType.video].contains(mediaStream.type))
      .take(2);

  final fields = [
    EmbedFieldBuilder(name: 'User', value: userString, isInline: false),
    EmbedFieldBuilder(name: 'Progress', value: progress, isInline: true),
    EmbedFieldBuilder(name: "Premiere Date", value: premiereDateString, isInline: true),
    getExternalUrlsEmbedField(nowPlayingItem.externalUrls?.toList() ?? []),
    ...getMediaInfoEmbedFields(primaryMediaStreams),
  ];

  final footer = EmbedFooterBuilder(text: "Jellyfin instance: ${client.name}");

  if (nowPlayingItem.type == BaseItemKind.episode) {
    return EmbedBuilder(
      author: EmbedAuthorBuilder(
          name: nowPlayingItem.seriesName!, iconUrl: client.getItemPrimaryImage(nowPlayingItem.seriesId!)),
      thumbnail: EmbedThumbnailBuilder(url: client.getItemPrimaryImage(nowPlayingItem.id!)),
      title: '${nowPlayingItem.seasonName} Episode ${nowPlayingItem.indexNumber} - ${nowPlayingItem.name}',
      description: nowPlayingItem.overview,
      fields: fields,
      footer: footer,
    );
  }

  if (nowPlayingItem.type == BaseItemKind.movie) {
    return EmbedBuilder(
      thumbnail: EmbedThumbnailBuilder(url: client.getItemPrimaryImage(nowPlayingItem.id!)),
      title: nowPlayingItem.name,
      description: nowPlayingItem.overview,
      fields: fields,
      footer: footer,
    );
  }

  if (nowPlayingItem.type == BaseItemKind.audio) {
    final artist = (nowPlayingItem.albumArtists as Iterable<NameGuidPair>? ?? []).first;

    return EmbedBuilder(
      author: EmbedAuthorBuilder(name: artist.name!, iconUrl: client.getItemPrimaryImage(artist.id!)),
      thumbnail: EmbedThumbnailBuilder(url: client.getItemPrimaryImage(nowPlayingItem.albumId!)),
      title: '${nowPlayingItem.album} - ${nowPlayingItem.name} (Track ${nowPlayingItem.indexNumber})',
      fields: fields,
      footer: footer,
    );
  }

  return null;
}

final jellyfin = ChatGroup(
  "jellyfin",
  "Jellyfin Testing Commands",
  checks: [administratorCheck],
  children: [
    ChatCommand(
      "current-sessions",
      "Displays current sessions",
      id("jellyfin-current-sessions", (ChatContext context,
          [@Description("Name of instance. Default selected if not provided") String? instanceName]) async {
        final client =
            await JellyfinModule.instance.getClient(JellyfinIdentificationModel(context.guild!.id, instanceName));
        if (client == null) {
          return context.respond(MessageBuilder(content: "Invalid Jellyfin instance"));
        }

        final currentSessions = await client.getCurrentSessions();
        if (currentSessions.isEmpty) {
          return context.respond(MessageBuilder(content: "No one watching currently"));
        }

        return currentSessions.map((sessionInfo) => buildSessionEmbed(sessionInfo, client)).nonNulls.toList();
      }),
    ),
    ChatCommand(
        'add-instance',
        "Add new instance to config",
        id("jellyfin-current-sessions", (InteractionChatContext context) async {
          final modalResponse = await context.getModal(title: "New Instance Configuration", components: [
            TextInputBuilder(customId: "name", style: TextInputStyle.short, label: "Instance Name"),
            TextInputBuilder(customId: "base_url", style: TextInputStyle.short, label: "Base Url"),
            TextInputBuilder(customId: "api_token", style: TextInputStyle.short, label: "API Token"),
            TextInputBuilder(customId: "is_default", style: TextInputStyle.short, label: "Is Default (True/False)"),
          ]);

          final config = await JellyfinModule.instance.createJellyfinConfig(
            modalResponse['name']!,
            modalResponse['base_url']!,
            modalResponse['api_token']!,
            modalResponse['is_default']?.toLowerCase() == 'true',
            modalResponse.guild!.id,
          );

          modalResponse.respond(MessageBuilder(content: "Added new jellyfin instance with name: ${config.name}"));
        })),
  ],
);
