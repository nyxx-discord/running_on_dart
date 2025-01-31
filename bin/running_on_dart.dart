import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/running_on_dart.dart';

void main(List<String> args) async {
  if (handleCli(args)) {
    return;
  }

  final commands = CommandsPlugin(
    prefix: null,
    guild: devGuildId,
    options: CommandsOptions(logErrors: dev, type: CommandType.slashOnly),
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
    ..addCommand(kavita)
    ..addConverter(settingsConverter)
    ..addConverter(manageableTagConverter)
    ..addConverter(durationConverter)
    ..addConverter(reminderConverter)
    ..addConverter(packageDocsConverter)
    ..addConverter(jellyfinConfigConverter)
    ..addConverter(jellyfinConfigUserConverter)
    ..addConverter(kavitaConfigConverter)
    ..addConverter(kavitaUserConfigsConverter);

  commands.onCommandError.listen(handleException);

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

  await setupContainer(client);

  WebServer().startServer();
}
