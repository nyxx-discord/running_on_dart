import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/modules/bot_start_duration.dart';
import 'package:running_on_dart/src/modules/docs.dart';
import 'package:running_on_dart/src/modules/reminder.dart';
import 'package:running_on_dart/src/modules/tag.dart';
import 'package:running_on_dart/src/settings.dart';
import 'package:running_on_dart/src/util/util.dart';

final info = ChatCommand(
  'info',
  'Get info about the bot',
  id('info', (ChatContext context) async {
    final color = getRandomColor();
    final currentUser = await context.client.user.get();

    final startDate = Injector.appInstance.get<BotStartDuration>().startDate;
    final startDateStr =
        "${startDate.format(TimestampStyle.longDateTime)} (${startDate.format(TimestampStyle.relativeTime)})";

    final docsUpdatedDate = Injector.appInstance.get<DocsModule>().lastUpdate;
    final docsUpdateStr = docsUpdatedDate != null
        ? "${docsUpdatedDate.format(TimestampStyle.longDateTime)} (${docsUpdatedDate.format(TimestampStyle.relativeTime)})"
        : "Never";

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
        EmbedFieldBuilder(
            name: 'Cached channels', value: context.client.channels.cache.length.toString(), isInline: true),
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
        EmbedFieldBuilder(
            name: 'Tags in guild',
            value:
                Injector.appInstance.get<TagModule>().countCachedTags(context.guild?.id ?? context.user.id).toString(),
            isInline: true),
        EmbedFieldBuilder(
            name: 'Current reminders',
            value: Injector.appInstance.get<ReminderModule>().reminders.length.toString(),
            isInline: true),
        EmbedFieldBuilder(name: 'Uptime', value: startDateStr, isInline: false),
        EmbedFieldBuilder(name: 'Docs Update', value: docsUpdateStr, isInline: false),
      ],
    );

    await context.respond(
      MessageBuilder(
        embeds: [embed],
        components: [
          ActionRowBuilder(components: [
            ButtonBuilder.link(
                url: context.client.application.getInviteUri(scopes: ['bot', 'applications.commands']),
                label: 'Add ROD to your guild'),
            ButtonBuilder.link(
                url: Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), label: 'Special link for special people')
          ]),
        ],
      ),
    );
  }),
);
