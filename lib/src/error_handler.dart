import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

final Logger _logger = Logger('ROD.CommandErrors');

void commandErrorHandler(CommandsException error) async {
  if (error is CommandInvocationException) {
    IContext context = error.context;

    String? title;
    String? description;

    if (error is CheckFailedException) {
      title = "You can't use this command!";
      description = 'This command can only be used by certain users in certain contexts.'
          ' Check that you have permission to execute the command, or contact a developer for more information.';
    } else if (error is NotEnoughArgumentsException) {
      title = 'Not enough arguments';
      description = "You didn't provide enough arguments for this command."
          " Please try again and use the Slash Command menu for help, or contact a developer for more information.";
    } else if (error is BadInputException) {
      title = "Couldn't parse input";
      description = "Your command couldn't be executed because we were unable to understand your input."
          " Please try again with different inputs or contact a developer for more information.";
    }

    // Send a generic "an error occurred" response
    EmbedBuilder embed = EmbedBuilder()
      ..color = DiscordColor.red
      ..title = title ?? 'An error has occurred'
      ..description = description ?? "Your command couldn't be executed because of an error. Please contact a developer for more information."
      ..addFooter((footer) {
        footer.text = error.runtimeType.toString();
      })
      ..timestamp = DateTime.now();

    await context.respond(MessageBuilder.embed(embed));
    return;
  }

  _logger.shout('Unhandled exception: $error');
}
