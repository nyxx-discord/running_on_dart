import 'package:collection/collection.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/modules/kavita.dart';

Stream<MessageBuilder> getSearchEmbedPages(Iterable<SeriesItem> items, AuthenticatedKavitaClient client) async* {
  for (final itemSlice in items.slices(2)) {
    final attachments = <AttachmentBuilder>[];

    final embeds = Stream.fromIterable(itemSlice).asyncMap((item) async {
      final attachment =
          AttachmentBuilder(data: await client.getSeriesCover(item.seriesId), fileName: 'series-cover.jpg');
      attachments.add(attachment);

      return EmbedBuilder(
        title: item.name,
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
