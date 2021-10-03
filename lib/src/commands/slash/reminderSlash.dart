import 'package:nyxx/nyxx.dart';
import "package:nyxx_interactions/interactions.dart";
import "package:running_on_dart/src/modules/reminder/reminder.dart";

Future<void> reminderAddSlash(SlashCommandInteractionEvent event) async {
  await event.acknowledge();

  final authorId = event.interaction.guild?.id != null
      ? event.interaction.memberAuthor!.id
      : event.interaction.userAuthor!.id;

  final messageArg = event.getArg("message").value.toString();
  final triggerAt = parseFromString(event.getArg("trigger-at").value.toString());

  final result = await createReminder(
      authorId,
      event.interaction.channel.id,
      triggerAt,
      messageArg
  );

  if (result) {
    return event.respond(MessageBuilder.content("All right, <t:${triggerAt.millisecondsSinceEpoch /~ 1000}:R> will remind about: $messageArg"));
  }

  return event.respond(MessageBuilder.content("Internal server error. Report to developer"));
}

DateTime parseFromString(String durationString) {
  final yearsRegex = RegExp(r"(\d+)(years|year|y)");
  final monthsRegex = RegExp(r"(\d+)(months|month|mon)");
  final daysRegex = RegExp(r"(\d+)(days|day|d)");
  final hoursRegex = RegExp(r"(\d+)(hours|hour|h)");
  final minutesRegex = RegExp(r"(\d+)(minutes|minute|min|m)");
  final secondsRegex = RegExp(r"(\d+)(seconds|second|secs|sec|s)");

  final dateTime = DateTime.now();

  final yearMatch = yearsRegex.firstMatch(durationString);
  if (yearMatch != null) {
    final yearNumber = yearMatch.group(1);
    if (yearNumber != null) {
      dateTime.add(Duration(days: 365 * int.parse(yearNumber)));
    }
  }

  final monthsMatch = monthsRegex.firstMatch(durationString);
  if (monthsMatch != null) {
    final monthNumber = monthsMatch.group(1);
    if (monthNumber != null) {
      dateTime.add(Duration(days: 30 * int.parse(monthNumber)));
    }
  }

  final daysMatch = daysRegex.firstMatch(durationString);
  if (daysMatch != null) {
    final daysNumber = daysMatch.group(1);
    if (daysNumber != null) {
      dateTime.add(Duration(days: int.parse(daysNumber)));
    }
  }

  final hoursMatch = hoursRegex.firstMatch(durationString);
  if (hoursMatch != null) {
    final hoursNumber = hoursMatch.group(1);
    if (hoursNumber != null) {
      dateTime.add(Duration(hours: int.parse(hoursNumber)));
    }
  }

  final minutesMatch = minutesRegex.firstMatch(durationString);
  if (minutesMatch != null) {
    final minutesNumber = minutesMatch.group(1);
    if (minutesNumber != null) {
      dateTime.add(Duration(minutes: int.parse(minutesNumber)));
    }
  }

  final secondsMatch = secondsRegex.firstMatch(durationString);
  if (secondsMatch != null) {
    final secondNumber = secondsMatch.group(1);
    if (secondNumber != null) {
      dateTime.add(Duration(seconds: int.parse(secondNumber)));
    }
  }

  return dateTime;
}
