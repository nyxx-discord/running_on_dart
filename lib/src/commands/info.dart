import 'dart:io';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/util.dart';

String getCurrentMemoryString() {
  final current = (ProcessInfo.currentRss / 1024 / 1024).toStringAsFixed(2);
  final rss = (ProcessInfo.maxRss / 1024 / 1024).toStringAsFixed(2);
  return '$current/$rss MB';
}

ChatCommand info = ChatCommand(
  'info',
  'Get generic information about the bot',
  id('info', (IChatContext context) async {
    final color = getRandomColor();

    final embed = EmbedBuilder()
      ..color = color
      ..addAuthor((author) {
        author.name = (context.client as INyxxWebsocket).self.tag;
        author.iconUrl = (context.client as INyxxWebsocket).self.avatarURL();
        author.url = 'https://github.com/nyxx-discord/nyxx';
      })
      ..addFooter((footer) {
        footer.text = 'nyxx ${Constants.version}'
            ' | ROD v$version'
            ' | Shard ${(context.guild?.shard.id ?? 0) + 1} of ${(context.client as INyxxWebsocket).shards}'
            ' | Dart SDK ${Platform.version.split('(').first}';
      })
      ..addField(
          name: 'Cached guilds',
          content: context.client.guilds.length,
          inline: true)
      ..addField(
          name: 'Cached users',
          content: context.client.users.length,
          inline: true)
      ..addField(
          name: 'Cached channels',
          content: context.client.channels.length,
          inline: true)
      ..addField(
        name: 'Cached voice states',
        content: context.client.guilds.values
            .map((g) => g.voiceStates.length)
            .fold<num>(0, (value, element) => value + element),
        inline: true,
      )
      ..addField(
          name: 'Shard count',
          content: (context.client as INyxxWebsocket).shards,
          inline: true)
      ..addField(
        name: 'Cached messages',
        content: context.client.channels.values
            .whereType<ITextChannel>()
            .map((c) => c.messageCache.length)
            .fold<num>(0, (value, element) => value + element),
        inline: true,
      )
      ..addField(
          name: 'Memory usage (current/RSS)',
          content: getCurrentMemoryString(),
          inline: true)
      ..addField(
          name: 'Uptime',
          content: TimeStampStyle.relativeTime.format(context.client.startTime))
      ..addField(
          name: 'Last documentation cache update',
          content: DocsService.instance.lastUpdate == null
              ? 'never'
              : TimeStampStyle.relativeTime
                  .format(DocsService.instance.lastUpdate!));

    await context.respond(ComponentMessageBuilder()
      ..embeds = [embed]
      ..addComponentRow(
        ComponentRowBuilder()
          ..addComponent(
            LinkButtonBuilder(
              'Add Running on Dart to your server',
              (context.client as INyxxWebsocket).app.getInviteUrl(),
            ),
          ),
      ));
  }),
);
