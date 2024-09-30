import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/services/feature_settings.dart';

final featureSettings = ChatGroup(
  'settings',
  'Manage enabled features in this guild',
  checks: [
    PermissionsCheck(Permissions.manageGuild),
    GuildCheck.all(),
  ],
  children: [
    ChatCommand(
      'enable',
      'Enable or update a setting for this guild',
      id('settings-enable', (ChatContext context, @Description('The setting to enable') Setting setting,
          [@Description('Additional data for features that require it') String? data]) async {
        if (setting.requiresData && data == null) {
          final embed = EmbedBuilder(
              title: 'Missing required data',
              color: DiscordColor.parseHexString("#FF0000"),
              description: 'The setting `${setting.name}` requires the `data` argument to be specified.'
                  ' Please re-run the command and specify the additional data required, or contact a developer for more details.');

          await context.respond(MessageBuilder(embeds: [embed]));
          return;
        }

        final featureSetting = FeatureSetting(
          setting: setting,
          guildId: context.guild!.id,
          whoEnabled: context.user.id,
          addedAt: DateTime.now(),
          data: data,
        );

        await FeatureSettingsService.instance.enable(featureSetting);

        await context.respond(MessageBuilder(content: 'Successfully enabled setting!'));
      }),
    ),
    ChatCommand(
      'disable',
      'Disable a setting for this guild',
      id('settings-disable', (
        ChatContext context,
        @Description('The setting to enable') Setting setting,
      ) async {
        final featureSetting = await FeatureSettingsRepository.instance.fetchSetting(setting, context.guild!.id);

        if (featureSetting != null) {
          FeatureSettingsService.instance.disable(featureSetting);
        }

        await context.respond(MessageBuilder(content: 'Successfully disabled setting!'));
      }),
    ),
  ],
);
