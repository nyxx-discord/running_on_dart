import "package:duration_parser/duration_parser.dart";
import "package:nyxx/nyxx.dart";
import "package:nyxx_interactions/interactions.dart";
import "package:running_on_dart/src/modules/reminder/reminder.dart";

Future<void> reminderAddSlash(SlashCommandInteractionEvent event) async {
  await event.acknowledge();

  final authorId = event.interaction.guild?.id != null
      ? event.interaction.memberAuthor!.id
      : event.interaction.userAuthor!.id;

  final messageArg = event.getArg("message").value.toString();
  final triggerAt = DateTime.now().add(
      parseStringToDuration(event.getArg("trigger-at").value.toString())
  );

  final result = await createReminder(
      authorId,
      event.interaction.channel.id,
      triggerAt,
      messageArg
  );

  if (result) {
    return event.respond(MessageBuilder.content("All right, <t:${triggerAt.millisecondsSinceEpoch ~/ 1000}:R> will remind about: `$messageArg`"));
  }

  return event.respond(MessageBuilder.content("Internal server error. Report to developer"));
}

Future<void> getUserRemainders(SlashCommandInteractionEvent event) async {
  await event.acknowledge(hidden: true);

  final authorId = event.interaction.guild?.id != null
      ? event.interaction.memberAuthor!.id
      : event.interaction.userAuthor!.id;

  final remainders = fetchRemaindersForUser(authorId);

  if (remainders.isEmpty) {
    return event.respond(MessageBuilder.content("You dont have any remainders at the moment"));
  }

  final stringBuffer = StringBuffer("Your current remainders:\n");
  for (final remainder in remainders) {
    stringBuffer.writeln("- [ID: ${remainder.id}] <t:${remainder.triggerDate.millisecondsSinceEpoch ~/ 1000}:R> - `${remainder.message}`\n");
  }
  stringBuffer.writeln("Remainders are cached for 30s. This could not be complete");

  await event.respond(MessageBuilder.content(stringBuffer.toString()), hidden: true);
}
