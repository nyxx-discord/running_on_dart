import "package:nyxx_interactions/interactions.dart";
import 'package:running_on_dart/src/modules/reminder/reminder.dart';

Future<void> reminderAddSlash(SlashCommandInteractionEvent event) async {

  final authorId = event.interaction.guild?.id != null
      ? event.interaction.memberAuthor!.id
      : event.interaction.userAuthor!.id;

  // final result = await createReminder(
  //   authorId,
  //   event.interaction.channel.id,
  //   event.interaction.
  // );
}
