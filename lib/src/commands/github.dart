import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/settings.dart';

final github = ChatGroup('github', 'Get information about nyxx on GitHub', children: [
  ChatCommand(
    'info',
    "General information about nyxx's GitHub",
    id('github-info', (ChatContext context) => context.respond(MessageBuilder(content: defaultGithubResponse.trim()))),
  ),
]);
