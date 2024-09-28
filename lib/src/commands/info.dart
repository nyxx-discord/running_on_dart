import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/settings.dart';
import 'package:running_on_dart/src/util/util.dart';

final info = ChatCommand(
  'info',
  'Get info about the bot',
  id('info', (ChatContext context) async {
    final color = getRandomColor();
    final currentUser = await context.client.user.get();

    final embed = EmbedBuilder(
      color: color,
      author: EmbedAuthorBuilder(
        name: currentUser.username,
        iconUrl: currentUser.avatar.url,
        url: Uri.parse(ApiOptions.nyxxRepositoryUrl),
      ),
      footer: EmbedFooterBuilder(
          text: 'nyxx ${ApiOptions.nyxxVersion}'
              ' | ROD $version'
              ' | Dart SDK ${getDartPlatform()}'),
      fields: [
        EmbedFieldBuilder(name: 'Cached guilds', value: context.client.guilds.cache.length.toString(), isInline: true),
        EmbedFieldBuilder(name: 'Cached users', value: context.client.users.cache.length.toString(), isInline: true),
        EmbedFieldBuilder(name: 'Cached channels', value: context.client.channels.cache.length.toString(), isInline: true),
        EmbedFieldBuilder(
            name: 'Cached voice states',
            value: context.client.guilds.cache.values
                .map((g) => g.voiceStates.length)
                .fold<num>(0, (value, element) => value + element)
                .toString(),
            isInline: true),
        EmbedFieldBuilder(name: 'Shard count', value: context.client.gateway.shards.length.toString(), isInline: true),
        EmbedFieldBuilder(
            name: 'Cached messages',
            value: context.client.channels.cache.values
                .whereType<TextChannel>()
                .map((c) => c.messages.cache.length)
                .fold<num>(0, (value, element) => value + element)
                .toString(),
            isInline: true),
        EmbedFieldBuilder(name: 'Memory usage (current/RSS)', value: getCurrentMemoryString(), isInline: true),
        EmbedFieldBuilder(name: 'Uptime', value: 'TODO: ', isInline: true),
      ],
    );

    await context.respond(
      MessageBuilder(
        embeds: [embed],
        components: [
          ActionRowBuilder(components: [
            ButtonBuilder.link(url: Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), label: 'Add ROD to your guild')
          ]),
        ],
      ),
    );
  }),
);
