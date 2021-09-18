import "package:nyxx/nyxx.dart" show EmbedBuilder, MessageBuilder;

import "package:running_on_dart/src/modules/docs.dart" show basePath, getDocDefinition, searchDocs;

Future<MessageBuilder> docsGetMessageBuilder(String phrase) async {
  final searchString = phrase.split(" ").last.split("#|.");
  final docsDef = await getDocDefinition(searchString.first, searchString.length > 1 ? searchString.last : null);

  if (docsDef == null) {
    return MessageBuilder.content("Cannot find docs for what you typed");
  }

  return MessageBuilder.embed(EmbedBuilder()
    ..addField(name: "Type", content: docsDef.type, inline: true)
    ..addField(name: "Name", content: docsDef.name, inline: true)
    ..description = "[${phrase.split(" ").last}](${docsDef.absoluteUrl})");
}

Future<MessageBuilder> docsSearchMessageBuilder(String phrase) async {
  final query = phrase.split(" ").last;
  final results = searchDocs(query);

  if(results.isEmpty) {
    return MessageBuilder.content("Nothing found matching: `$query`");
  }

  final buffer = StringBuffer();
  for (final def in results) {
    buffer.write("[${def.name}](${def.absoluteUrl})\n");
  }

  final embed = EmbedBuilder()
    ..description = buffer.toString();

  return MessageBuilder.embed(embed);
}

Future<MessageBuilder> docsLinksMessageBuilder() async => MessageBuilder.content(basePath);
