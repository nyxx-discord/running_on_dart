import 'dart:async';

import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/modules/kavita.dart';

final pageNumberFormat = NumberFormat('000');

Stream<MessageBuilder> getSearchEmbedPages(Iterable<SeriesItem> items, AuthenticatedKavitaClient client) async* {
  for (final itemSlice in items.slices(2)) {
    final attachments = <AttachmentBuilder>[];

    final embeds = Stream.fromIterable(itemSlice).asyncMap((item) async {
      final attachment =
          AttachmentBuilder(data: await client.getSeriesCover(item.seriesId), fileName: 'series-cover.jpg');
      attachments.add(attachment);

      return EmbedBuilder(
        title: '${item.name} (${item.seriesId})',
        fields: [
          EmbedFieldBuilder(name: 'Library', value: item.libraryName, isInline: true),
        ],
        thumbnail: EmbedThumbnailBuilder(url: Uri.parse('attachment://series-cover.jpg')),
      );
    });

    yield MessageBuilder(
      embeds: await embeds.toList(),
      attachments: attachments,
    );
  }
}

Stream<FutureOr<MessageBuilder> Function()> generateReadingPaginationFactories(
    ContinuePoint continuePoint, AuthenticatedKavitaClient client, int seriesId, bool saveReadProgress) async* {
  for (var i = 0; i < continuePoint.pages; i += 1) {
    yield () {
      if (saveReadProgress) {
        client.saveContinuePoint(seriesId, continuePoint.volumeId, continuePoint.chapterId, i + 1);
      }

      return generateReadingPage(i, continuePoint.chapterId, client);
    };
  }
}

Future<MessageBuilder> generateReadingPage(int page, int chapterId, AuthenticatedKavitaClient client) async {
  final pageData = await client.getChapterImage(chapterId, page);

  return MessageBuilder(
      attachments: [AttachmentBuilder(data: pageData, fileName: '${pageNumberFormat.format(page)}.jpg')]);
}
