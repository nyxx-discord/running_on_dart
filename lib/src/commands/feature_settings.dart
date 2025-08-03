import 'package:collection/collection.dart';
import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/models/feature_settings.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/modules/feature_settings.dart';
import 'package:running_on_dart/src/util/util.dart';

final featureSettings = ChatGroup(
  'settings',
  'Manage enabled features in this guild',
  checks: [PermissionsCheck(Permissions.manageGuild), GuildCheck.all()],
  children: [
    ChatCommand(
      'enable',
      'Enable or update a setting for this guild',
      id('settings-enable', (
        InteractionChatContext context,
        @Description('The setting to enable') Setting setting,
      ) async {
        SettingData? data;
        if (setting is! Setting<NoData>) {
          final modal = await context.getModal(title: "Configuration", components: setting.getConfigurationFields());

          data = setting.parseFromConfiguration(modal.asMap());
          if (data == null) {
            return context.respond(
              MessageBuilder(content: "Cannot properly parse settings data. Please contact administrator"),
            );
          }
        }

        final featureSetting = FeatureSetting.create(
          setting: setting,
          guildId: context.guild!.id,
          whoEnabled: context.user.id,
          data: data,
        );

        await Injector.appInstance.get<FeatureSettingsModule>().enable(featureSetting);

        return context.respond(MessageBuilder(content: 'Successfully enabled setting!'));
      }),
    ),
    ChatCommand(
      'disable',
      'Disable a setting for this guild',
      id('settings-disable', (ChatContext context, @Description('The setting to enable') Setting setting) async {
        final featureSetting = await Injector.appInstance.get<FeatureSettingsRepository>().fetchSetting(
          setting,
          context.guild!.id,
        );

        if (featureSetting != null) {
          Injector.appInstance.get<FeatureSettingsModule>().disable(featureSetting);
        }

        await context.respond(MessageBuilder(content: 'Successfully disabled setting!'));
      }),
    ),
    ChatCommand(
      "show-configuration",
      "Show current configuration for settings",
      id('settings-show-configuration', (ChatContext context) async {
        final settings = await Injector.appInstance.get<FeatureSettingsRepository>().fetchSettingsForGuild(
          context.guild!.id,
        );

        final messageBuilders = settings.map((setting) {
          final embed = EmbedBuilder(
            title: setting.setting.name,
            description: setting.setting.description,
            fields: [
              EmbedFieldBuilder(
                name: 'Added at',
                value: setting.addedAt.format(TimestampStyle.shortDate),
                isInline: true,
              ),
              EmbedFieldBuilder(name: 'Added by', value: userMention(setting.whoEnabled), isInline: true),
              if (settings is! Setting<NoData>)
                EmbedFieldBuilder(name: 'Additional data', value: setting.rawData ?? '[EMPTY]', isInline: false),
            ],
          );

          return MessageBuilder(embeds: [embed]);
        });

        final paginator = await pagination.builders(messageBuilders.toList());

        return context.respond(paginator);
      }),
      options: CommandOptions(defaultResponseLevel: ResponseLevel.private),
    ),
    ChatCommand(
      'list',
      'List available settings',
      id('settings-list', (ChatContext context) async {
        final embeds = Setting.values.map((s) {
          return EmbedBuilder(
            title: s.name,
            description: s.description,
            fields: [
              if (s is! Setting<NoData>)
                EmbedFieldBuilder(
                  name: 'Data fields',
                  value: s.getConfigurationFields().map((e) => e.customId).join(", "),
                  isInline: false,
                ),
            ],
          );
        });

        final builders = embeds.slices(4).map((embeds) => MessageBuilder(embeds: embeds)).toList();

        final paginator = await pagination.builders(builders);
        return context.respond(paginator);
      }),
    ),
  ],
);
