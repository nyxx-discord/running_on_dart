import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/models/reminder.dart';
import 'package:running_on_dart/src/services/reminder.dart';

ChatGroup reminder = ChatGroup(
  'reminder',
  'Create and manage reminders',
  children: [
    ChatCommand(
      'create',
      'Create a new reminder',
      (
        IChatContext context,
        @Name('in') @Description('The amount of time after which the reminder should trigger') Duration offset,
        @Description('A short message to attach to the reminder') String message,
      ) async {
        DateTime triggerAt = DateTime.now().add(offset);

        await addReminder(Reminder(
          userId: context.user.id,
          channelId: context.channel.id,
          messageId: context is MessageChatContext ? context.message.id : null,
          triggerAt: triggerAt,
          addedAt: DateTime.now(),
          message: message,
        ));

        await context.respond(
          MessageBuilder.content('Alright ')
            ..appendMention(context.user)
            ..append(', ')
            ..appendTimestamp(triggerAt, style: TimeStampStyle.relativeTime)
            ..append(': ')
            ..append(message),
        );
      },
    ),
  ],
);
