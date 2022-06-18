import 'package:duration/duration.dart';
import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

final _logger = Logger('ROD.CommandErrors');

void commandErrorHandler(CommandsException error) async {
  if (error is CommandInvocationException) {
    final context = error.context;

    String? title;
    String? description;

    if (error is CheckFailedException) {
      if (error.failed.name.contains("music")) {
        switch (error.failed.name) {
          case 'musicConnectedToVC':
            await context.respond(MessageBuilder.content('I have to be in a voice channel to use this command'));
            break;
          case 'musicNotConnectedToVC':
            await context.respond(MessageBuilder.content("I'm already connected to a voice channel"));
            break;
          case 'musicSameVC':
            await context.respond(MessageBuilder.content("I'm already being used on other voice channel"));
            break;
          case 'musicUserConnectedToVC':
            await context.respond(MessageBuilder.content('You need to be connected to a voice channel to use this command'));
            break;
          default:
            break;
        }

        return;
      }

      final failed = error.failed;

      if (failed is CooldownCheck) {
        title = 'Command on cooldown';
        description = "You can't use this command right now because it is on cooldown. Please wait ${prettyDuration(failed.remaining(context))} and try again.";
      } else {
        title = "You can't use this command!";
        description = 'This command can only be used by certain users in certain contexts.'
            ' Check that you have permission to execute the command, or contact a developer for more information.';
      }
    } else if (error is NotEnoughArgumentsException) {
      title = 'Not enough arguments';
      description = "You didn't provide enough arguments for this command."
          " Please try again and use the Slash Command menu for help, or contact a developer for more information.";
    } else if (error is BadInputException) {
      title = "Couldn't parse input";
      description = "Your command couldn't be executed because we were unable to understand your input."
          " Please try again with different inputs or contact a developer for more information.";
    } else if (error is UncaughtException) {
      _logger.severe('Uncaught exception in command: ${error.exception}');
    }

    // Send a generic "an error occurred" response
    final embed = EmbedBuilder()
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
