import "package:human_duration_parser/human_duration_parser.dart";
import "package:nyxx/nyxx.dart";
import "package:nyxx_interactions/nyxx_interactions.dart";
import "package:running_on_dart/src/internal/utils.dart";
import "package:running_on_dart/src/modules/reminder/reminder.dart";

Future<void> reminderAddSlash(ISlashCommandInteractionEvent event) async {
  await event.acknowledge();

  final authorId = getAuthorId(event);

  final messageArg = event.getArg("message").value.toString();
  final triggerAt = DateTime.now().add(parseStringToDuration(event.getArg("trigger-at").value.toString()));

  final result = await createReminder(authorId, event.interaction.channel.id, triggerAt, messageArg);

  if (result) {
    return event.respond(MessageBuilder.content("All right, <t:${triggerAt.millisecondsSinceEpoch ~/ 1000}:R> will remind about: `$messageArg`"));
  }

  return event.respond(MessageBuilder.content("Internal server error. Report to developer"));
}

Future<void> reminderGetUsers(ISlashCommandInteractionEvent event) async {
  await event.acknowledge(hidden: true);

  final authorId = event.interaction.guild?.id != null ? event.interaction.memberAuthor!.id : event.interaction.userAuthor!.id;

  final reminders = fetchRemindersForUser(authorId);

  if (reminders.isEmpty) {
    return event.respond(MessageBuilder.content("You dont have any reminders at the moment"));
  }

  final stringBuffer = StringBuffer("Your current reminders:\n");
  for (final reminder in reminders) {
    stringBuffer.writeln("- [ID: ${reminder.id}] <t:${reminder.triggerDate.millisecondsSinceEpoch ~/ 1000}:R> - ${reminder.message}\n");
  }
  stringBuffer.writeln("Reminders are cached for 30s. This could not be complete list of all reminders");

  await event.respond(MessageBuilder.content(stringBuffer.toString()), hidden: true);
}

Future<void> remindersClear(ISlashCommandInteractionEvent event) async {
  await event.acknowledge(hidden: true);

  final authorId = getAuthorId(event);

  final result = await clearRemindersForUser(authorId);
  return event.respond(MessageBuilder.content("Deleted $result reminders"));
}

Future<void> reminderRemove(ISlashCommandInteractionEvent event) async {
  await event.acknowledge(hidden: true);

  final authorId = getAuthorId(event);
  final id = event.getArg("id").value as int;

  final result = await removeReminderForUser(id, authorId);
  if (!result) {
    return event.respond(MessageBuilder.content("There was an problem deleting your reminder"));
  }

  return event.respond(MessageBuilder.content("Removed reminder with id: $id"));
}
