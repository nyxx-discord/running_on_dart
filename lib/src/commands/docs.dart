import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/docs.dart';
import 'package:running_on_dart/src/util.dart';

ChatCommand docs = ChatCommand.textOnly(
  'docs',
  'Search and get documentation for various packages',
  (IChatContext context) => context.respond(MessageBuilder.content(defaultDocsResponse.trim())),
  children: [
    ChatCommand(
      'info',
      'Get generic documentation information',
      (IChatContext context) => context.respond(MessageBuilder.content(defaultDocsResponse.trim())),
    ),
    ChatCommand(
      'get',
      'Get documentation for a specific API element',
      (
        IChatContext context,
        @Description('The element to get documentation for') DocEntry element,
      ) async {
        DiscordColor color = getRandomColor();

        EmbedBuilder embed = EmbedBuilder()
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
      },
    ),
  ],
);
