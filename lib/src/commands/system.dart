import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/checks.dart';

ChatGroup system =
    ChatGroup('system', 'Commands designed for ROD administrators',
        children: [
          ChatCommand(
              "clear-cache",
              "Clear bot cache",
              id("clear-cache", (IChatContext context) async {
                context.client.channels.clear();
                context.client.users.clear();

                await context.respond(
                    MessageBuilder.content("Cache cleared successfully!"));
              }))
        ],
        checks: [administratorCheck, GuildCheck.id(adminGuildId)],
        options: CommandOptions(hideOriginalResponse: true));
