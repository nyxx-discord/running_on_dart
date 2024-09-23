import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/commands/info.dart';

void main() async {
  final commands = CommandsPlugin(
    prefix: mentionOr((_) => prefix),
    guild: devGuildId,
    options: CommandsOptions(logErrors: true, type: CommandType.slashOnly),
  );

  commands
    ..addCommand(info)
    ..addCommand(featureSettings);

  final client = await Nyxx.connectGateway(token, intents, options: GatewayClientOptions(
    plugins: [
      Logging(),
      CliIntegration(),
      IgnoreExceptions(),
      commands,
    ],
  ));

  await DatabaseService.instance.awaitReady();

  PoopNameModule.init(client);
  JoinLogsModule.init(client);
}
