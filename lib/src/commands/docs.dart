import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/checks.dart';
import 'package:running_on_dart/src/converter.dart';
import 'package:running_on_dart/src/models/docs.dart';
import 'package:running_on_dart/src/modules/docs.dart';
import 'package:running_on_dart/src/settings.dart';
import 'package:running_on_dart/src/util/util.dart';

final docs = ChatGroup(
  'docs',
  'Search and get documentation for various packages',
  children: [
    ChatCommand(
      "refresh",
      "Refresh docs manually",
      id("docs-refresh", (ChatContext context) {
        DocsModule.instance.updateCache();

        context.respond(MessageBuilder(content: 'Manual docs refresh executed!'));
      }),
      checks: [
        administratorCheck,
        administratorGuildCheck,
      ],
    ),
    ChatCommand(
      'info',
      'Get generic documentation information',
      id('docs-info', (ChatContext context) => context.respond(MessageBuilder(content: defaultDocsResponse.trim()))),
    ),
    ChatCommand(
      'get',
      'Get documentation for a specific API element',
      id('docs-get', (
        ChatContext context,
        @Description('The element to get documentation for') DocEntry element,
      ) async {
        final embed = EmbedBuilder(
            color: getRandomColor(),
            title: '${element.displayName} ${element.type}',
            description: '''
Documentation: [${element.name}](${element.urlToDocs})
Package: [${element.packageName}](https://pub.dev/packages/${element.packageName})
''',
            footer: EmbedFooterBuilder(text: element.qualifiedName));

        await context.respond(MessageBuilder(embeds: [embed]));
      }),
    ),
    ChatCommand(
      'search',
      'Search for documentation',
      id('docs-search', (
        ChatContext context,
        @Description('The query to search for') @Autocomplete(autocompleteQueryWithPackage) String query, [
        @Description('The package to search in') PackageDocs? package,
      ]) async {
        final searchResults = DocsModule.instance.search(query, package);

        if (searchResults.isEmpty) {
          await context.respond(MessageBuilder(
              embeds: [EmbedBuilder(title: 'No results', color: DiscordColor.parseHexString("#FF0000"))]));
          return;
        }

        final paginator = await pagination.builders(_getPaginationBuilders(searchResults, query, package), userId: context.user.id);

        await context.respond(paginator);
      }),
    ),
  ],
);

List<MessageBuilder> _getPaginationBuilders(Iterable<DocEntry> searchResults, String query, PackageDocs? package) {
  var pageCount = 1;

  final foldedResults = searchResults.fold<List<List<String>>>([[]], (pages, entry) {
    final entryContent = '[${entry.displayName} ${entry.type}](${entry.urlToDocs})';

    // +1 for newline
    var wouldBeLength = pages.last.join('\n').length + entryContent.length + 1;

    if (wouldBeLength > 1024 || pages.last.length >= 10) {
      pages.add([]);
      pageCount++;
    }

    return pages..last.add(entryContent);
  });

  return foldedResults.asMap().entries.map((entry) {
    final embed = EmbedBuilder(
        color: getRandomColor(),
        title: 'Search results - $query',
        fields: [
          EmbedFieldBuilder(
              name: 'Results in ${package != null ? 'package ${package.packageName}' : 'all packages'}',
              value: entry.value.join('\n'),
              isInline: false),
        ],
        footer: EmbedFooterBuilder(text: 'Page ${entry.key + 1} of $pageCount'));

    return MessageBuilder(embeds: [embed]);
  }).toList();
}
