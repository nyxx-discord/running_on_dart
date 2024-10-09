import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/modules/jellyfin.dart';
import 'package:tentacle/tentacle.dart';

final episodeSeriesNumberFormat = NumberFormat("00");
final itemRatingNumberFormat = NumberFormat("0.0");
final itemCriticRatingNumberFormat = NumberFormat("00");

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

Stream<MessageBuilder> buildMediaInfoBuilders(List<BaseItemDto> items, JellyfinClientWrapper client) async* {
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

EmbedBuilder? buildMediaEmbedBuilder(BaseItemDto item, JellyfinClientWrapper client) {
  final criticRating = item.criticRating != null ? "${itemCriticRatingNumberFormat.format(item.criticRating)}%" : '?';
  final communityRating = item.communityRating != null ? itemRatingNumberFormat.format(item.communityRating) : '?';
  final rating = "$communityRating / $criticRating";

  final fields = [
    EmbedFieldBuilder(name: "Rating (Community/Critic)", value: rating, isInline: true),
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
      ],
    );
  }

  if (item.type == BaseItemKind.movie) {
    return EmbedBuilder(
      thumbnail: EmbedThumbnailBuilder(url: client.getItemPrimaryImage(item.id!)),
      title: "${item.name} (${item.productionYear.toString()})",
      description: item.overview,
      fields: [
        EmbedFieldBuilder(
            name: "Length", value: parseDurationFromTicks(item.runTimeTicks!).formatShort(), isInline: true),
        ...fields,
      ],
    );
  }

  return null;
}
