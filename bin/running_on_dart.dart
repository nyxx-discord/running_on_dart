import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/services/reminder.dart';

void main() async {
  // Create nyxx client and nyxx_commands plugin
  final INyxxWebsocket client = NyxxFactory.createNyxxWebsocket(token, intents);

  CommandsPlugin commands = CommandsPlugin(
    prefix: mentionOr((_) => prefix),
    guild: devGuildId,
    options: CommandsOptions(logErrors: false),
  );

  // Register our commands
  commands
    ..addCommand(ping)
    ..addCommand(info)
    ..addCommand(avatar)
    ..addCommand(voice)
    ..addCommand(docs)
    ..addCommand(reminder);

  // Add our error handler
  commands.onCommandError.listen(commandErrorHandler);

  // Add our custom converters
  commands
    ..addConverter(docEntryConverter)
    ..addConverter(packageDocsConverter)
    ..addConverter(durationConverter);

  // Add logging, CLI, exceptions and commands plugin to our client
  client
    ..registerPlugin(Logging())
    ..registerPlugin(CliIntegration())
    ..registerPlugin(IgnoreExceptions())
    ..registerPlugin(commands);

  // Initialise our services
  initDocsCache();
  await initDatabase();
  await initReminders(client);

  // Connect
  await client.connect();
}
