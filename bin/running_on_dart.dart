import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/commands/tag.dart';

void main() async {
  final commands = CommandsPlugin(
    prefix: mentionOr((_) => prefix),
    guild: devGuildId,
    options: CommandsOptions(logErrors: true, type: CommandType.slashOnly),
  );

  commands
    ..addCommand(avatar)
    ..addCommand(docs)
    ..addCommand(featureSettings)
    ..addCommand(github)
    ..addCommand(info)
    ..addCommand(ping)
    ..addCommand(tag)
    ..addConverter(settingsConverter)
    ..addConverter(manageableTagConverter);

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
  DocsModule.init();
}
