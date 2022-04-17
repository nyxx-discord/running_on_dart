import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/running_on_dart.dart';

void main() {
  // Create nyxx client and nyxx_commands plugin
  final INyxxWebsocket client = NyxxFactory.createNyxxWebsocket(token, intents);

  CommandsPlugin commands = CommandsPlugin(
    prefix: mentionOr((_) => prefix),
    guild: devGuildId,
  );

  // Register our commands
  commands
    ..addCommand(ping)
    ..addCommand(info);

  // Add logging, CLI, exceptions and commands plugin to our client, then connect
  client
    ..registerPlugin(Logging())
    ..registerPlugin(CliIntegration())
    ..registerPlugin(IgnoreExceptions())
    ..registerPlugin(commands)
    ..connect();
}
