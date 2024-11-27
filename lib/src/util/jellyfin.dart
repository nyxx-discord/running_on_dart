import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/external/sonarr.dart';
import 'package:running_on_dart/src/modules/jellyfin.dart';
import 'package:running_on_dart/src/util/audio_channel_layout.dart';
import 'package:running_on_dart/src/util/util.dart';
import 'package:tentacle/tentacle.dart';

final episodeSeriesNumberFormat = NumberFormat("00");
final itemRatingNumberFormat = NumberFormat("0.0");
final itemCriticRatingNumberFormat = NumberFormat("00");

Duration parseDurationFromTicks(int ticks) => Duration(microseconds: ticks ~/ 10);

String formatSeriesEpisodeString(int seriesNumber, int episodeNumber) =>
    'S${episodeSeriesNumberFormat.format(seriesNumber)}E${episodeSeriesNumberFormat.format(episodeNumber)}';

String formatShortDateTimeWithRelative(DateTime dateTime) =>
    "${dateTime.format(TimestampStyle.shortDateTime)} (${dateTime.format(TimestampStyle.relativeTime)})";

String formatProgress(int currentPositionTicks, int totalTicks) {
  final progressPercentage = currentPositionTicks / totalTicks * 100;

  final currentPositionDuration = parseDurationFromTicks(currentPositionTicks);
  final totalDuration = parseDurationFromTicks(totalTicks);

  return "${currentPositionDuration.formatShort()}/${totalDuration.formatShort()} (${progressPercentage.toStringAsFixed(2)}%)";
}

Iterable<EmbedBuilder> getSonarrCalendarEmbeds(Iterable<CalendarItem> calendarItems) sync* {
  for (final item in calendarItems.take(5)) {
    final seriesPosterUrl = item.series.images.firstWhereOrNull((image) => image.coverType == 'poster');

    yield EmbedBuilder(
      title: '${formatSeriesEpisodeString(item.seasonNumber, item.episodeNumber)} ${item.title} (${item.series.title})',
      description: item.overview,
      fields: [
        EmbedFieldBuilder(name: "Air date", value: formatShortDateTimeWithRelative(item.airDateUtc), isInline: false),
        EmbedFieldBuilder(name: "Avg runtime", value: "${item.series.runtime} mins", isInline: true),
      ],
      thumbnail: seriesPosterUrl != null ? EmbedThumbnailBuilder(url: Uri.parse(seriesPosterUrl.remoteUrl)) : null,
    );
  }
}

Iterable<EmbedFieldBuilder> getMediaInfoEmbedFields(Iterable<MediaStream> mediaStreams) sync* {
  for (final mediaStream in mediaStreams) {
    final displayTitle = getMediaInfoEmbedDisplayTitle(mediaStream);
    if (displayTitle == null) {
      continue;
    }

    yield EmbedFieldBuilder(name: "Media Info (${mediaStream.type!.name})", value: displayTitle, isInline: true);
  }
}

String? getMediaInfoEmbedDisplayTitle(MediaStream mediaStream) {
  final bitrate = ((mediaStream.bitRate ?? 0) / 1024 / 1024).toStringAsFixed(2);

  String? titlePrefix;

  switch (mediaStream.type) {
    case MediaStreamType.audio:
      String? channelLayout = AudioChannelLayout.parse(mediaStream.channelLayout)?.toStringWithPrefix();
      channelLayout ??= toBeginningOfSentenceCase(mediaStream.channelLayout);

      String? codec = mediaStream.profile;
      codec ??= switch (mediaStream.codec) {
        'eac3' => 'Dolby Digital',
        _ => mediaStream.codec?.toUpperCase(),
      };
      codec = stripNonAscii(codec ?? '');

      titlePrefix = '$channelLayout $codec';
      break;
    case MediaStreamType.video:
      titlePrefix =
          '${mediaStream.height}p ${mediaStream.videoRange?.name.toUpperCase()} ${mediaStream.codec?.toUpperCase()}';
    default:
      break;
  }

  return "$titlePrefix ($bitrate Mbps)";
}

EmbedFieldBuilder getExternalUrlsEmbedField(Iterable<ExternalUrl> externalUrls) {
  final fieldValue = externalUrls.map((externalUrl) => '[${externalUrl.name}](${externalUrl.url})').join(' ');

  return EmbedFieldBuilder(name: "External Urls", value: fieldValue.toString(), isInline: false);
}

Iterable<EmbedFieldBuilder> getMediaPlaybackInfoFields(SessionInfoDto sessionInfo) {
  if (sessionInfo.transcodingInfo == null) {
    final mediaStreams = (sessionInfo.nowPlayingItem!.mediaStreams as Iterable<MediaStream>? ?? []);

    if (sessionInfo.nowPlayingItem!.type == BaseItemKind.audio) {
      return getMediaInfoEmbedFields(mediaStreams.where((mediaStream) => mediaStream.type == MediaStreamType.audio));
    }

    return getMediaInfoEmbedFields([
      ...mediaStreams.where((mediaStream) => mediaStream.type == MediaStreamType.video),
      ...mediaStreams.where((mediaStream) =>
          mediaStream.type == MediaStreamType.audio && mediaStream.index == sessionInfo.playState!.audioStreamIndex),
    ]);
  }

  final transcodingInfo = sessionInfo.transcodingInfo!;

  final finalBitrate = ((transcodingInfo.bitrate ?? 0) / 1024 / 1024).toStringAsFixed(2);

  final completionInfo = transcodingInfo.completionPercentage != null && transcodingInfo.framerate != null
      ? ' - ${transcodingInfo.completionPercentage!.toStringAsFixed(2)}% (${transcodingInfo.framerate} fps)'
      : '';

  final transcodingReason = getTranscodingReason(transcodingInfo);
  final reasonInfo = transcodingReason != null ? " ($transcodingReason)" : '';

  final transCodingInfoString =
      '${transcodingInfo.height}p (${transcodingInfo.videoCodec} ${transcodingInfo.audioCodec} ${transcodingInfo.container}) $finalBitrate Mbps$completionInfo$reasonInfo';

  return [EmbedFieldBuilder(name: "Transcoding", value: transCodingInfoString, isInline: false)];
}

String? getTranscodingReason(TranscodingInfo transcodingInfo) {
  if ((transcodingInfo.isVideoDirect ?? false) && !(transcodingInfo.isAudioDirect ?? true)) {
    return 'Repackaging';
  }

  final transcodingReason = (transcodingInfo.transcodeReasons?.toList() ?? []).map((r) {
    return switch (r) {
      TranscodingInfoTranscodeReasonsEnum(:final name) when name == 'containerNotSupported' =>
        'Container not supported',
      TranscodingInfoTranscodeReasonsEnum(:final name) when name == 'containerBitrateExceedsLimit' =>
        'Bitrate exceeds Limit',
      TranscodingInfoTranscodeReasonsEnum(:final name) when name.contains('video') => 'Video not supported',
      TranscodingInfoTranscodeReasonsEnum(:final name) when name.contains('audio') => 'Audio not supported',
      _ => 'Other'
    };
  });

  if (transcodingReason.isNotEmpty) {
    return null;
  }

  return transcodingReason.join(", ");
}

EmbedBuilder? buildSessionEmbed(SessionInfoDto sessionInfo, AuthenticatedJellyfinClient client) {
  final nowPlayingItem = sessionInfo.nowPlayingItem;
  if (nowPlayingItem == null) {
    return null;
  }

  final progress = formatProgress(sessionInfo.playState!.positionTicks ?? 1, nowPlayingItem.runTimeTicks ?? 1);
  final premiereDateString = nowPlayingItem.premiereDate!.format(TimestampStyle.longDate);

  var mediaPlaybackInfo = getMediaPlaybackInfoFields(sessionInfo);

  final fields = [
    EmbedFieldBuilder(name: 'Progress', value: progress, isInline: true),
    EmbedFieldBuilder(name: "Premiere Date", value: premiereDateString, isInline: true),
    getExternalUrlsEmbedField(nowPlayingItem.externalUrls?.toList() ?? []),
    ...mediaPlaybackInfo,
  ];

  final footer = EmbedFooterBuilder(text: "Jellyfin instance: ${client.configUser.config!.name}");
  final author = EmbedAuthorBuilder(
    name: '${sessionInfo.userName} on ${sessionInfo.deviceName}',
    iconUrl: client.getUserImage(sessionInfo.userId!),
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
      title: '${artist.name!} - ${nowPlayingItem.name} (Track ${nowPlayingItem.indexNumber})',
      fields: [EmbedFieldBuilder(name: 'Album', value: '${nowPlayingItem.album}', isInline: false), ...fields],
      footer: footer,
    );
  }

  return null;
}

Stream<MessageBuilder> buildMediaInfoBuilders(List<BaseItemDto> items, AuthenticatedJellyfinClient client) async* {
  for (final slice in items.slices(2)) {
    final messageBuilder = MessageBuilder(embeds: []);

    for (final item in slice) {
      final embed = buildMediaEmbedBuilder(item, client);
      if (embed == null) {
        continue;
      }

      messageBuilder.embeds!.add(embed);
    }

    yield messageBuilder;
  }
}

EmbedBuilder? buildMediaEmbedBuilder(BaseItemDto item, AuthenticatedJellyfinClient client) {
  final criticRating = item.criticRating != null ? "${itemCriticRatingNumberFormat.format(item.criticRating)}%" : '?';
  final communityRating = item.communityRating != null ? itemRatingNumberFormat.format(item.communityRating) : '?';
  final rating = "$communityRating / $criticRating";

  final fields = [
    EmbedFieldBuilder(name: "Rating (Community/Critic)", value: rating, isInline: true),
    if ([BaseItemKind.episode, BaseItemKind.movie].contains(item.type))
      EmbedFieldBuilder(
          name: "Length", value: parseDurationFromTicks(item.runTimeTicks!).formatShort(), isInline: true),
    EmbedFieldBuilder(
        name: "Url", value: "[Open in Jellyfin](${client.getJellyfinItemUrl(item.id!)})", isInline: false),
  ];

  if (item.type == BaseItemKind.episode) {
    final episodeIndex =
        'S${episodeSeriesNumberFormat.format(item.parentIndexNumber)}E${episodeSeriesNumberFormat.format(item.indexNumber)}';

    return EmbedBuilder(
      thumbnail: EmbedThumbnailBuilder(url: client.getItemPrimaryImage(item.id!)),
      title: '${item.seriesName!} - $episodeIndex - ${item.name}',
      description: item.overview,
      fields: fields,
    );
  }

  if (item.type == BaseItemKind.series) {
    final runtime = "${item.premiereDate!.year} - ${item.endDate!.year}";

    return EmbedBuilder(
      thumbnail: EmbedThumbnailBuilder(url: client.getItemPrimaryImage(item.id!)),
      title: item.name,
      description: item.overview,
      fields: [
        EmbedFieldBuilder(name: "Runtime", value: runtime, isInline: true),
        EmbedFieldBuilder(name: "Status", value: item.status.toString(), isInline: true),
        ...fields,
        EmbedFieldBuilder(
            name: 'Avg Length', value: parseDurationFromTicks(item.runTimeTicks!).formatShort(), isInline: true)
      ],
    );
  }

  if (item.type == BaseItemKind.movie) {
    return EmbedBuilder(
      thumbnail: EmbedThumbnailBuilder(url: client.getItemPrimaryImage(item.id!)),
      title: "${item.name} (${item.productionYear.toString()})",
      description: item.overview,
      fields: fields,
    );
  }

  return null;
}

EmbedBuilder getUserInfoEmbed(UserDto currentUser, AuthenticatedJellyfinClient client) {
  final thumbnail =
      currentUser.primaryImageTag != null ? EmbedThumbnailBuilder(url: client.getUserImage(currentUser.id!)) : null;

  return EmbedBuilder(
    thumbnail: thumbnail,
    title: currentUser.name,
    fields: [
      EmbedFieldBuilder(
          name: "Last login", value: formatShortDateTimeWithRelative(currentUser.lastLoginDate!), isInline: true),
      EmbedFieldBuilder(
          name: "Last activity", value: formatShortDateTimeWithRelative(currentUser.lastActivityDate!), isInline: true),
      EmbedFieldBuilder(
          name: "Is admin?", value: currentUser.policy?.isAdministrator == true ? 'true' : 'false', isInline: true),
      EmbedFieldBuilder(name: "Links", value: '[Profile](${client.getUserProfile(currentUser.id!)})', isInline: false)
    ],
  );
}

MessageBuilder getJellyfinLoginMessage(
        {required Snowflake userId, required String configName, required Snowflake parentId, bool isReAuth = false}) =>
    MessageBuilder(
        content:
            '${isReAuth ? 'Session expired. ' : ''}Login using username and password or using Quick Connect feature',
        components: [
          ActionRowBuilder(components: [
            ButtonBuilder.primary(
                customId: JellyfinLoginCustomId.username(userId: userId, configName: configName, parentId: parentId)
                    .toString(),
                label: "Username login"),
            ButtonBuilder.primary(
                customId: JellyfinLoginCustomId.quickConnect(userId: userId, configName: configName, parentId: parentId)
                    .toString(),
                label: "Quick Connect login"),
          ])
        ]);
