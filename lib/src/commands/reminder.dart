import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_pagination/nyxx_pagination.dart';
import 'package:running_on_dart/src/models/reminder.dart';
import 'package:running_on_dart/src/services/reminder.dart';
import 'package:running_on_dart/src/util.dart';

ChatGroup reminder = ChatGroup(
  'reminder',
  'Create and manage reminders',
  children: [
    ChatCommand(
      'create',
      'Create a new reminder',
      id('reminder-create', (
        IChatContext context,
        @Name('in')
        @Description(
            'The amount of time after which the reminder should trigger')
        Duration offset,
        @Description('A short message to attach to the reminder')
        String message,
      ) async {
        final triggerAt = DateTime.now().add(offset);

        final replyMessage =
            await context.respond(MessageBuilder.content('Alright ')
              ..appendMention(context.user)
              ..append(', Creating reminder: ')
              ..appendTimestamp(triggerAt, style: TimeStampStyle.relativeTime)
              ..append(': ')
              ..append(message));

        await ReminderService.instance.addReminder(Reminder(
          userId: context.user.id,
          channelId: context.channel.id,
          messageId: replyMessage.id,
          triggerAt: triggerAt,
          addedAt: DateTime.now(),
          message: message,
        ));

        await replyMessage.edit(MessageBuilder.content('Alright ')
          ..appendMention(context.user)
          ..append(', ')
          ..appendTimestamp(triggerAt, style: TimeStampStyle.relativeTime)
          ..append(': ')
          ..append(message));
      }),
    ),
    ChatCommand(
      'clear',
      'Remove all your reminders',
      id('reminder-clear', (IChatContext context) async {
        await Future.wait(ReminderService.instance
            .getUserReminders(context.user.id)
            .map((reminder) =>
                ReminderService.instance.removeReminder(reminder)));

        await context.respond(
            MessageBuilder.content('Successfully cleared all your reminders.'));
      }),
    ),
    ChatCommand(
      'remove',
      'Remove a reminder',
      id('reminder-remove', (
        IChatContext context,
        @Description('The reminder to remove') Reminder reminder,
      ) async {
        await ReminderService.instance.removeReminder(reminder);

        await context.respond(
            MessageBuilder.content('Successfully removed your reminder.'));
      }),
    ),
    ChatCommand(
      'list',
      'List all your active reminders',
      id('reminder-list', (IChatContext context) async {
        final reminders = ReminderService.instance
            .getUserReminders(context.user.id)
            .toList()
          ..sort((a, b) => a.triggerAt.compareTo(b.triggerAt));

        final entries = reminders.asMap().entries.map((entry) {
          final index = entry.key;
          final reminder = entry.value;

          return EmbedBuilder()
            ..color = getRandomColor()
            ..title = 'Reminder ${index + 1} of ${reminders.length}'
            ..addField(
              name: 'Triggers at',
              content:
                  '${TimeStampStyle.longDateTime.format(reminder.triggerAt)} (${TimeStampStyle.relativeTime.format(reminder.triggerAt)})',
            )
            ..addField(
                name: 'Content',
                content: reminder.message.length > 2048
                    ? reminder.message.substring(0, 2045) + '...'
                    : reminder.message);
        }).toList();

        if (entries.isEmpty) {
          await context.respond(MessageBuilder.content("No reminders!"));
          return;
        }

        final paginator = EmbedComponentPagination(
          context.commands.interactions,
          entries,
        );

        await context.respond(paginator.initMessageBuilder());
      }),
    ),
  ],
);
