import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

final Logger logger = Logger('ROD');

void commandErrorHandler(CommandsException error) async {
  if (error is CommandInvocationException) {
    IContext context = error.context;

    if (error is CheckFailedException) {
      await context.respond(MessageBuilder.content("You can't use this command!"));
      return;
    }

    // Send a generic "an error occurred" response
    EmbedBuilder embed = EmbedBuilder()
      ..color = DiscordColor.red
      ..title = 'An error has occurred'
      ..description = "Your command couldn't be executed because of an error. Please contact a developer for more information."
      ..addFooter((footer) {
        footer.text = error.runtimeType.toString();
      })
      ..timestamp = DateTime.now();

    await context.respond(MessageBuilder.embed(embed));
  }

  logger.shout('Unhandled exception: $error');
}
