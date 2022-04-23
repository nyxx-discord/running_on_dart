import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/checks.dart';
import 'package:running_on_dart/src/models/guild_settings.dart';
import 'package:running_on_dart/src/util.dart';

ChatGroup settings = ChatGroup(
  'settings',
  'Manage enabled features in this guild',
  checks: [
    Check.any([
      administratorCheck,
      Check((context) async => (await context.member?.effectivePermissions)?.manageGuild ?? false),
    ]),
    GuildCheck.all(),
  ],
  children: [
    ChatCommand(
      'enable',
      'Enable or update a setting for this guild',
      <T>(
        IChatContext context,
        @Description('The setting to enable') Setting<T> setting, [
        @Description('Additional data for features that require it') String? data,
      ]) async {
        if (setting.requiresData && data == null) {
          EmbedBuilder embed = EmbedBuilder()
            ..color = DiscordColor.red
            ..title = 'Missing required data'
            ..description = 'The setting `${setting.value}` requires the `data` argument to be specified.'
                ' Please re-run the command and specify the additional data required, or contact a developer for more details.';

          await context.respond(MessageBuilder.embed(embed));
          return;
        }

        GuildSetting<T> guildSetting = GuildSetting.withData(
          setting: setting,
          guildId: context.guild!.id,
          whoEnabled: context.user.id,
          addedAt: DateTime.now(),
          data: data,
        );

        await GuildSettingsService.instance.enable(guildSetting);

        await context.respond(MessageBuilder.content('Successfully enabled setting!'));
      },
    ),
    ChatCommand(
      'disable',
      'Disable a setting for this guild',
      <T>(
        IChatContext context,
        @Description('The setting to disable') Setting<T> setting,
      ) async {
        GuildSetting<T>? guildSetting = await GuildSettingsService.instance.getSetting(setting, context.guild!.id);

        if (guildSetting != null) {
          await GuildSettingsService.instance.disable(guildSetting);
        }

        await context.respond(MessageBuilder.content('Successfully disabled setting!'));
      },
    ),
    ChatCommand(
      'list',
      'List all enabled features in this guild',
      (IChatContext context) async {
        EmbedBuilder embed = EmbedBuilder()
          ..color = getRandomColor()
          ..title = 'Enabled features';

        List<GuildSetting<dynamic>> guildSettings = [];

        for (final setting in Setting.values) {
          GuildSetting<dynamic>? guildSetting = await GuildSettingsService.instance.getSetting(setting, context.guild!.id);

          if (guildSetting != null) {
            guildSettings.add(guildSetting);
          }
        }

        embed.description =
            guildSettings.map((setting) => '- **${setting.setting.value}** ${setting.setting.requiresData ? ' (`${setting.data}`)' : ''}').join('\n');

        await context.respond(MessageBuilder.embed(embed));
      },
    ),
  ],
);
