import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/guild_settings.dart';
import 'package:running_on_dart/src/util.dart';

ChatGroup settings = ChatGroup(
  'settings',
  'Manage enabled features in this guild',
  checks: [
    PermissionsCheck(PermissionsConstants.manageGuild),
    GuildCheck.all(),
  ],
  children: [
    ChatCommand(
      'enable',
      'Enable or update a setting for this guild',
      id('settings-enable', <T>(
        IChatContext context,
        @Description('The setting to enable') Setting<T> setting, [
        @Description('Additional data for features that require it')
        String? data,
      ]) async {
        if (setting.requiresData && data == null) {
          final embed = EmbedBuilder()
            ..color = DiscordColor.red
            ..title = 'Missing required data'
            ..description =
                'The setting `${setting.value}` requires the `data` argument to be specified.'
                    ' Please re-run the command and specify the additional data required, or contact a developer for more details.';

          await context.respond(MessageBuilder.embed(embed));
          return;
        }

        final guildSetting = GuildSetting.withData(
          setting: setting,
          guildId: context.guild!.id,
          whoEnabled: context.user.id,
          addedAt: DateTime.now(),
          data: data,
        );

        await GuildSettingsService.instance.enable(guildSetting);

        await context
            .respond(MessageBuilder.content('Successfully enabled setting!'));
      }),
    ),
    ChatCommand(
      'disable',
      'Disable a setting for this guild',
      id('settings-disable', <T>(
        IChatContext context,
        @Description('The setting to disable') Setting<T> setting,
      ) async {
        final guildSetting = await GuildSettingsService.instance
            .getSetting(setting, context.guild!.id);

        if (guildSetting != null) {
          await GuildSettingsService.instance.disable(guildSetting);
        }

        await context
            .respond(MessageBuilder.content('Successfully disabled setting!'));
      }),
    ),
    ChatCommand(
      'list',
      'List all enabled features in this guild',
      id('settings-list', (IChatContext context) async {
        final embed = EmbedBuilder()
          ..color = getRandomColor()
          ..title = 'Enabled features';

        final guildSettings = <GuildSetting<dynamic>>[];

        for (final setting in Setting.values) {
          final guildSetting = await GuildSettingsService.instance
              .getSetting(setting, context.guild!.id);

          if (guildSetting != null) {
            guildSettings.add(guildSetting);
          }
        }

        embed.description = guildSettings
            .map((setting) =>
                '- **${setting.setting.value}** ${setting.setting.requiresData ? ' (`${setting.data}`)' : ''}')
            .join('\n');

        await context.respond(MessageBuilder.embed(embed));
      }),
    ),
  ],
);
