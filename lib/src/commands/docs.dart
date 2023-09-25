import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:nyxx_pagination/nyxx_pagination.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/docs.dart';
import 'package:running_on_dart/src/util.dart';

ChatCommand docs = ChatCommand(
  'docs',
  'Search and get documentation for various packages',
  id(
      'docs',
      (IChatContext context) =>
          context.respond(MessageBuilder.content(defaultDocsResponse.trim()))),
  children: [
    ChatCommand(
      'info',
      'Get generic documentation information',
      id(
          'docs-info',
          (IChatContext context) => context
              .respond(MessageBuilder.content(defaultDocsResponse.trim()))),
    ),
    ChatCommand(
      'get',
      'Get documentation for a specific API element',
      id('docs-get', (
        IChatContext context,
        @Description('The element to get documentation for') DocEntry element,
      ) async {
        final color = getRandomColor();

        final embed = EmbedBuilder()
          ..color = color
          ..title = '${element.displayName} ${element.type}'
          ..description = '''
Documentation: [${element.name}](${element.urlToDocs})
Package: [${element.packageName}](https://pub.dev/packages/${element.packageName})
'''
              .trim()
          ..addFooter((footer) {
            footer.text = element.qualifiedName;
          });

        await context.respond(MessageBuilder.embed(embed));
      }),
    ),
    ChatCommand(
      'search',
      'Search for documentation',
      id('docs-search', (
        IChatContext context,
        @Description('The query to search for')
        @Autocomplete(autocompleteQueryWithPackage)
        String query, [
        @Description('The package to search in') PackageDocs? package,
      ]) async {
        final searchResults = DocsService.instance.search(query, package);

        if (searchResults.isEmpty) {
          await context.respond(MessageBuilder.embed(EmbedBuilder()
            ..title = 'No results'
            ..color = DiscordColor.red));
          return;
        }

        var pageCount = 1;

        final paginator = EmbedComponentPagination(
          context.commands.interactions,
          // Chunk our results so we don't exceed 10 results per page or the 1024 field character limit
          searchResults
              .fold<List<List<String>>>([[]], (pages, entry) {
                final entryContent =
                    '[${entry.displayName} ${entry.type}](${entry.urlToDocs})';

                // +1 for newline
                var wouldBeLength =
                    pages.last.join('\n').length + entryContent.length + 1;

                if (wouldBeLength > 1024 || pages.last.length >= 10) {
                  pages.add([]);
                  pageCount++;
                }

                return pages..last.add(entryContent);
              })
              .asMap()
              .entries
              .map((entry) {
                final color = getRandomColor();

                return EmbedBuilder()
                  ..color = color
                  ..title = 'Search results - $query'
                  ..addField(
                    name:
                        'Results in ${package != null ? 'package ${package.packageName}' : 'all packages'}',
                    content: entry.value.join('\n'),
                  )
                  ..addFooter((footer) {
                    footer.text = 'Page ${entry.key + 1} of $pageCount';
                  });
              })
              .toList(),
        );

        await context.respond(paginator.initMessageBuilder());
      }),
    ),
  ],
);

/// Search autocomplete, but only include elements from a given package (if there is one selected).
Iterable<ArgChoiceBuilder> autocompleteQueryWithPackage(
    AutocompleteContext context) {
  final selectedPackageName = context.interactionEvent.options
      .cast<
          IInteractionOption?>() // Cast to IInteractionOption? so we can return `null` in orElse
      .firstWhere((element) => element?.name == 'package', orElse: () => null)
      ?.value
      ?.toString();

  PackageDocs? selectedPackage;
  if (selectedPackageName != null) {
    selectedPackage = DocsService.instance.getPackageDocs(selectedPackageName);
  }

  return [
    // Allow the user to select their current value
    if (context.currentValue.isNotEmpty)
      ArgChoiceBuilder(context.currentValue, context.currentValue),
    ...DocsService.instance
        .search(context.currentValue, selectedPackage)
        .take(context.currentValue.isEmpty ? 25 : 24)
        .map((e) => ArgChoiceBuilder(e.displayName, e.qualifiedName)),
  ];
}
