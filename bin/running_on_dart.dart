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
    ..addConverter(reminderConverter);

  commands.onCommandError.listen((error) {
    if (error is CheckFailedException) {
      error.context.respond(MessageBuilder(content: "Sorry, you can't use that command!"));
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

  final db = DatabaseService();
  await db.awaitReady();

  Injector.appInstance
    ..registerSingleton(() => client)
    ..registerSingleton(() => db)
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
    ..registerSingleton(() => JellyfinModule());
}
