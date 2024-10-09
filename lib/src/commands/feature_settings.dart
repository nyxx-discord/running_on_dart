import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
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

        await Injector.appInstance.get<FeatureSettingsService>().enable(featureSetting);

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
        final featureSetting =
            await Injector.appInstance.get<FeatureSettingsRepository>().fetchSetting(setting, context.guild!.id);

        if (featureSetting != null) {
          Injector.appInstance.get<FeatureSettingsService>().disable(featureSetting);
        }

        await context.respond(MessageBuilder(content: 'Successfully disabled setting!'));
      }),
    ),
    ChatCommand(
        "show-configuration",
        "Show current configuration for settings",
        id('settings-show-configuration', (ChatContext context) async {
          final settings =
              await Injector.appInstance.get<FeatureSettingsRepository>().fetchSettingsForGuild(context.guild!.id);

          final messageBuilders = settings.map((setting) {
            final dataFieldValue = switch (setting.setting.type) {
              DataType.channelMention => channelMention(Snowflake.parse(setting.data!)),
              _ => setting.data ?? '[EMPTY]'
            };

            final embed = EmbedBuilder(title: setting.setting.name, description: setting.setting.description, fields: [
              EmbedFieldBuilder(
                  name: 'Added at', value: setting.addedAt.format(TimestampStyle.shortDate), isInline: true),
              EmbedFieldBuilder(name: 'Added by', value: userMention(setting.whoEnabled), isInline: true),
              EmbedFieldBuilder(name: 'Additional data', value: dataFieldValue, isInline: false),
            ]);

            return MessageBuilder(embeds: [embed]);
          });

          final paginator = await pagination.builders(messageBuilders.toList());

          return context.respond(paginator);
        }),
        options: CommandOptions(defaultResponseLevel: ResponseLevel.private)),
  ],
);
