import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/services/bot_info.dart';
import 'package:running_on_dart/src/util/util.dart';

final info = ChatCommand(
  'info',
  'Get info about the bot',
  id('info', (ChatContext context) async {
    final currentUser = await context.client.user.get();
    final botInfo = await Injector.appInstance.get<BotInfoService>().getCurrentBotInfo();

    final startDateStr =
        "${botInfo.uptime.format(TimestampStyle.longDateTime)} (${botInfo.uptime.format(TimestampStyle.relativeTime)})";
    final docsUpdateStr =
        botInfo.docsUpdate != null
            ? "${botInfo.docsUpdate!.format(TimestampStyle.longDateTime)} (${botInfo.docsUpdate!.format(TimestampStyle.relativeTime)})"
            : "Never";

    final embed = EmbedBuilder(
      color: getRandomColor(),
      author: EmbedAuthorBuilder(
        name: currentUser.username,
        iconUrl: currentUser.avatar.url,
        url: Uri.parse(ApiOptions.nyxxRepositoryUrl),
      ),
      footer: EmbedFooterBuilder(
        text:
            'nyxx ${botInfo.nyxxVersion}'
            ' | Bot ${botInfo.version}'
            ' | Frontend ${botInfo.frontendVersion}'
            ' | Dart SDK ${botInfo.dartPlatform}',
      ),
      fields: [
        EmbedFieldBuilder(name: 'Cached guilds', value: botInfo.cachedGuilds.toString(), isInline: true),
        EmbedFieldBuilder(name: 'Cached users', value: botInfo.cachedUsers.toString(), isInline: true),
        EmbedFieldBuilder(name: 'Cached channels', value: botInfo.cachedChannels.toString(), isInline: true),
        EmbedFieldBuilder(name: 'Cached voice states', value: botInfo.cachedVoiceStates.toString(), isInline: true),
        EmbedFieldBuilder(name: 'Shard count', value: botInfo.shardCount.toString(), isInline: true),
        EmbedFieldBuilder(name: 'Cached messages', value: botInfo.cachedMessages.toString(), isInline: true),
        EmbedFieldBuilder(name: 'Memory usage (current/RSS)', value: botInfo.memoryUserString, isInline: true),
        EmbedFieldBuilder(name: 'Tags in guild', value: botInfo.totalTagsCount.toString(), isInline: true),
        EmbedFieldBuilder(name: 'Current reminders', value: botInfo.totalRemainderCount.toString(), isInline: true),
        EmbedFieldBuilder(name: 'Uptime', value: startDateStr, isInline: false),
        EmbedFieldBuilder(name: 'Docs Update', value: docsUpdateStr, isInline: false),
      ],
    );

    await context.respond(
      MessageBuilder(
        embeds: [embed],
        components: [
          ActionRowBuilder(
            components: [
              ButtonBuilder.link(
                url: context.client.application.getInviteUri(scopes: ['bot', 'applications.commands']),
                label: 'Add ROD to your guild',
              ),
              ButtonBuilder.link(
                url: Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
                label: 'Special link for special people',
              ),
            ],
          ),
        ],
      ),
    );
  }),
);
