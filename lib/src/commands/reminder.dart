import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/models/reminder.dart';
import 'package:running_on_dart/src/modules/reminder.dart';
import 'package:running_on_dart/src/util/util.dart';

final reminder = ChatGroup(
  'reminder',
  'Create and manage reminders',
  children: [
    ChatCommand(
      'create',
      'Create a new reminder',
      id('reminder-create', (
        ChatContext context,
        @Name('in') @Description('The amount of time after which the reminder should trigger') Duration offset,
        @Description('A short message to attach to the reminder') String message,
      ) async {
        final triggerAt = DateTime.now().add(offset);

        final messageBuffer = StringBuffer('Alright ')
          ..write(context.user.mention)
          ..write(', Creating reminder: ')
          ..write(triggerAt.format(TimestampStyle.relativeTime))
          ..write(': ')
          ..write(message);

        final replyMessage = await context.respond(MessageBuilder(content: messageBuffer.toString()));

        await ReminderModule.instance.addReminder(Reminder(
          userId: context.user.id,
          channelId: context.channel.id,
          messageId: replyMessage.id,
          triggerAt: triggerAt,
          addedAt: DateTime.now(),
          message: message,
        ));

        final editMessageBuffer = StringBuffer('Alright ')
          ..write(context.user.mention)
          ..write(', ')
          ..write(triggerAt.format(TimestampStyle.relativeTime))
          ..write(': ')
          ..write(message);

        await replyMessage.edit(MessageUpdateBuilder(content: editMessageBuffer.toString()));
      }),
    ),
    ChatCommand(
      'clear',
      'Remove all your reminders',
      id('reminder-clear', (ChatContext context) async {
        await Future.wait(
            ReminderModule.instance.getUserReminders(context.user.id).map((reminder) => ReminderModule.instance.removeReminder(reminder)));

        await context.respond(MessageBuilder(content: 'Successfully cleared all your reminders.'));
      }),
    ),
    ChatCommand(
      'remove',
      'Remove a reminder',
      id('reminder-remove', (
        ChatContext context,
        @Description('The reminder to remove') Reminder reminder,
      ) async {
        await ReminderModule.instance.removeReminder(reminder);

        await context.respond(MessageBuilder(content: 'Successfully removed your reminder.'));
      }),
    ),
    ChatCommand(
      'list',
      'List all your active reminders',
      id('reminder-list', (ChatContext context) async {
        final reminders = ReminderModule.instance.getUserReminders(context.user.id).toList()
          ..sort((a, b) => a.triggerAt.compareTo(b.triggerAt));

        final entries = reminders.asMap().entries.map((entry) {
          final index = entry.key;
          final reminder = entry.value;

          final embed = EmbedBuilder(color: getRandomColor(), title: 'Reminder ${index + 1} of ${reminders.length}', fields: [
            EmbedFieldBuilder(
                name: 'Triggers at',
                value:
                    '${reminder.triggerAt.format(TimestampStyle.longDateTime)} (${reminder.triggerAt.format(TimestampStyle.relativeTime)})',
                isInline: false),
            EmbedFieldBuilder(
                name: 'Content',
                value: reminder.message.length > 2048 ? '${reminder.message.substring(0, 2045)}...' : reminder.message,
                isInline: false),
          ]);

          return MessageBuilder(embeds: [embed]);
        }).toList();

        if (entries.isEmpty) {
          await context.respond(MessageBuilder(content: "No reminders!"));
          return;
        }

        final paginator = await pagination.builders(entries);

        await context.respond(paginator);
      }),
    ),
  ],
);
