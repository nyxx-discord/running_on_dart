import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/commands/reminder.dart';
import 'package:running_on_dart/src/commands/tag.dart';
import 'package:running_on_dart/src/modules/bot_start_duration.dart';

import 'package:injector/injector.dart';
import 'package:running_on_dart/src/repository/feature_settings.dart';
import 'package:running_on_dart/src/repository/jellyfin_config.dart';
import 'package:running_on_dart/src/repository/reminder.dart';
import 'package:running_on_dart/src/repository/tag.dart';
import 'package:running_on_dart/src/services/feature_settings.dart';

import 'package:dio/dio.dart' show DioException;
import 'package:running_on_dart/src/util/jellyfin.dart';

void main() async {
  final commands = CommandsPlugin(
    prefix: null,
    guild: devGuildId,
    options: CommandsOptions(logErrors: dev),
  );

  commands
    ..addCommand(avatar)
    ..addCommand(docs)
    ..addCommand(featureSettings)
    ..addCommand(github)
    ..addCommand(info)
    ..addCommand(ping)
    ..addCommand(tag)
    ..addCommand(reminder)
    ..addCommand(admin)
    ..addCommand(jellyfin)
    ..addCommand(reminderMessageCommand)
    ..addConverter(settingsConverter)
    ..addConverter(manageableTagConverter)
    ..addConverter(durationConverter)
    ..addConverter(reminderConverter)
    ..addConverter(packageDocsConverter)
    ..addConverter(jellyfinConfigConverter)
    ..addConverter(jellyfinConfigUserConverter);

  commands.onCommandError.listen((error) async {
    if (error is CheckFailedException) {
      error.context.respond(MessageBuilder(content: "Sorry, you can't use that command!"));
      return;
    }

    if (error is UncaughtException) {
      final context = error.context;

      switch (error.exception) {
        // case JellyfinConfigNotFoundException(:final message):
        //   error.context.respond(MessageBuilder(content: message));
        //   break;
        case JellyfinAdminUserRequired _:
          context.respond(
              MessageBuilder(content: "This command can use only logged jellyfin users with administrator privileges."),
              level: ResponseLevel.private);
          break;
        case DioException(:final error) when error is JellyfinUnauthorizedException:
          final jellyfinConfigs = await Injector.appInstance
              .get<JellyfinModuleV2>()
              .getJellyfinConfigBasedOnPreviousLogin(context.user.id, context.guild?.id ?? context.user.id, error.host);

          if (jellyfinConfigs.length == 1) {
            final userConfig = jellyfinConfigs.first;
            final config =
                await Injector.appInstance.get<JellyfinModuleV2>().getJellyfinConfigById(userConfig.jellyfinConfigId);

            context.respond(
                getJellyfinLoginMessage(
                    userId: userConfig.userId, configName: config!.name, parentId: config.parentId, isReAuth: true),
                level: ResponseLevel.private);
            break;
          }

          context.respond(
              MessageBuilder(
                  content: 'Cannot provide config automatically. Login manually using: `/jellyfin user login`.'),
              level: ResponseLevel.private);
          break;
        case _:
          print(error.exception);
      }
    }
  });

  final client = await Nyxx.connectGateway(token, intents,
      options: GatewayClientOptions(
        plugins: [
          Logging(),
          CliIntegration(),
          IgnoreExceptions(),
          commands,
          pagination,
        ],
      ));

  Injector.appInstance
    ..registerSingleton(() => client)
    ..registerSingleton(() => DatabaseService())
    ..registerSingleton(() => FeatureSettingsRepository())
    ..registerSingleton(() => JellyfinConfigRepository())
    ..registerSingleton(() => ReminderRepository())
    ..registerSingleton(() => TagRepository())
    ..registerSingleton(() => FeatureSettingsService())
    ..registerSingleton(() => BotStartDuration())
    ..registerSingleton(() => PoopNameModule())
    ..registerSingleton(() => JoinLogsModule())
    ..registerSingleton(() => ReminderModule())
    ..registerSingleton(() => ModLogsModule())
    ..registerSingleton(() => TagModule())
    ..registerSingleton(() => DocsModule())
    ..registerSingleton(() => JellyfinModuleV2());

  await Injector.appInstance.get<DatabaseService>().init();
  await Injector.appInstance.get<JellyfinModuleV2>().init();
  await Injector.appInstance.get<DocsModule>().init();
  await Injector.appInstance.get<TagModule>().init();
  await Injector.appInstance.get<ModLogsModule>().init();
  await Injector.appInstance.get<ReminderModule>().init();
  await Injector.appInstance.get<JoinLogsModule>().init();
  await Injector.appInstance.get<PoopNameModule>().init();
  await Injector.appInstance.get<BotStartDuration>().init();
}
