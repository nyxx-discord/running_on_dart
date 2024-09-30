import 'package:intl/intl.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/checks.dart';
import 'package:running_on_dart/src/models/jellyfin_config.dart';
import 'package:running_on_dart/src/repository/jellyfin_config.dart';
import 'package:tentacle/tentacle.dart';

final episodeSeriesNumberFormat = NumberFormat("00");

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

  final mediaStreams = (nowPlayingItem.mediaStreams as Iterable<MediaStream>? ?? []);
  final primaryMediaStreams = [
    ...mediaStreams.where((mediaStream) => mediaStream.type == MediaStreamType.video),
    ...mediaStreams.where((mediaStream) =>
        mediaStream.type == MediaStreamType.audio && mediaStream.index == sessionInfo.playState!.audioStreamIndex),
  ];

  final fields = [
    EmbedFieldBuilder(name: 'Progress', value: progress, isInline: true),
    EmbedFieldBuilder(name: "Premiere Date", value: premiereDateString, isInline: true),
    getExternalUrlsEmbedField(nowPlayingItem.externalUrls?.toList() ?? []),
    ...getMediaInfoEmbedFields(primaryMediaStreams),
  ];

  final footer = EmbedFooterBuilder(text: "Jellyfin instance: ${client.name}");
  final author = EmbedAuthorBuilder(
    name: '${sessionInfo.userName} on ${sessionInfo.deviceName}',
    iconUrl: sessionInfo.userPrimaryImageTag != null ? client.getItemPrimaryImage(sessionInfo.userId!) : null,
  );

  if (nowPlayingItem.type == BaseItemKind.episode) {
    final episodeIndex =
        'S${episodeSeriesNumberFormat.format(nowPlayingItem.parentIndexNumber)}E${episodeSeriesNumberFormat.format(nowPlayingItem.indexNumber)}';

    return EmbedBuilder(
      author: author,
      thumbnail: EmbedThumbnailBuilder(url: client.getItemPrimaryImage(nowPlayingItem.id!)),
      title: '${nowPlayingItem.seriesName!} - $episodeIndex - ${nowPlayingItem.name}',
      description: nowPlayingItem.overview,
      fields: fields,
      footer: footer,
    );
  }

  if (nowPlayingItem.type == BaseItemKind.movie) {
    return EmbedBuilder(
      author: author,
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
      author: author,
      thumbnail: EmbedThumbnailBuilder(url: client.getItemPrimaryImage(nowPlayingItem.albumId!)),
      title: '${artist.name!} - ${nowPlayingItem.name}',
      fields: [
        EmbedFieldBuilder(
            name: 'Album', value: '${nowPlayingItem.album} (Track ${nowPlayingItem.indexNumber})', isInline: false),
        ...fields
      ],
      footer: footer,
    );
  }

  return null;
}

final jellyfin = ChatGroup(
  "jellyfin",
  "Jellyfin Testing Commands",
  checks: [
    jellyfinFeatureEnabledCheck,
  ],
  children: [
    ChatCommand(
        "current-sessions",
        "Displays current sessions",
        id("jellyfin-current-sessions", (ChatContext context,
            [@Description("Instance to use. Default selected if not provided")
            @UseConverter(jellyfinConfigConverter)
            JellyfinConfig? config]) async {
          final client =
              await JellyfinModule.instance.getClient(JellyfinIdentificationModel(context.guild!.id, config?.name));
          if (client == null) {
            return context.respond(MessageBuilder(content: "Invalid Jellyfin instance"));
          }

          final currentSessions = await client.getCurrentSessions();
          if (currentSessions.isEmpty) {
            return context.respond(MessageBuilder(content: "No one watching currently"));
          }

          final embeds = currentSessions.map((sessionInfo) => buildSessionEmbed(sessionInfo, client)).nonNulls.toList();
          context.respond(MessageBuilder(embeds: embeds));
        }),
        checks: [
          jellyfinFeatureUserCommandCheck,
        ]),
    ChatCommand(
        'add-instance',
        "Add new instance to config",
        id("jellyfin-new-instance", (InteractionChatContext context) async {
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
            modalResponse.guild?.id ?? modalResponse.user.id,
          );

          modalResponse.respond(MessageBuilder(content: "Added new jellyfin instance with name: ${config.name}"));
        }),
        checks: [
          jellyfinFeatureCreateInstanceCommandCheck,
        ]),
    ChatCommand(
        "transfer-config",
        "Transfers jellyfin instance config to another guild",
        id("jellyfin-transfer-config", (
          ChatContext context,
          @Description("Name of instance") @UseConverter(jellyfinConfigConverter) JellyfinConfig config,
          @Description("Guild or user id to copy to") Snowflake targetParentId, [
          @Description("Copy default flag?") bool copyDefaultFlag = false,
          @Description("New name for config. Copied from original if not provided") String? configName,
        ]) async {
          final newConfig = await JellyfinConfigRepository.instance.createJellyfinConfig(configName ?? config.name,
              config.basePath, config.token, copyDefaultFlag && config.isDefault, targetParentId);

          context.respond(
              MessageBuilder(content: 'Copied config: "${newConfig.name}" to parent: "${newConfig.parentId}"'));
        }),
        checks: [
          jellyfinFeatureAdminCommandCheck,
        ]),
    ChatCommand(
        "remove-config",
        "Removes config from current guild",
        id("jellyfin-remove-config", (ChatContext context,
            @Description("Name of instance") @UseConverter(jellyfinConfigConverter) JellyfinConfig config) async {
          await JellyfinModule.instance.deleteJellyfinConfig(config);

          context.respond(MessageBuilder(content: 'Delete config with name: "${config.name}"'));
        }),
        checks: [
          jellyfinFeatureAdminCommandCheck,
        ]),
  ],
);
