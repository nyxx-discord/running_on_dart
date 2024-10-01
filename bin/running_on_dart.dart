import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/commands/reminder.dart';
import 'package:running_on_dart/src/commands/tag.dart';
import 'package:running_on_dart/src/modules/bot_start_duration.dart';

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

  await DatabaseService.instance.awaitReady();

  PoopNameModule.init(client);
  JoinLogsModule.init(client);
  ReminderModule.init(client);
  ModLogsModule.init(client);
  TagModule.init();
  DocsModule.init();
  JellyfinModule.init();
  BotStartDuration.init();
}
