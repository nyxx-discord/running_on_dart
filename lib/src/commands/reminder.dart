import 'package:human_duration_parser/human_duration_parser.dart';
import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/models/reminder.dart';
import 'package:running_on_dart/src/modules/reminder.dart';
import 'package:running_on_dart/src/util/util.dart';

String _getReminderReadyMessageText(String userMention, DateTime triggerAt, String? message) {
  final buffer = StringBuffer('Alright ')
    ..write(userMention)
    ..write(', ')
    ..write(triggerAt.format(TimestampStyle.relativeTime));

  if (message != null) {
    buffer
      ..write(': ')
      ..write(message);
  }

  return buffer.toString();
}

Future<void> _createReminder(
        {required Snowflake userId,
        required Snowflake channelId,
        required Snowflake messageId,
        required DateTime triggerAt,
        required String message}) =>
    Injector.appInstance.get<ReminderModule>().addReminder(Reminder(
          userId: userId,
          channelId: channelId,
          messageId: messageId,
          triggerAt: triggerAt,
          addedAt: DateTime.now(),
          message: message,
        ));

final reminderMessageCommand = MessageCommand("create-reminder", (MessageContext context) async {
  final modal = await context.getModal(title: 'new Reminder', components: [
    TextInputBuilder(customId: 'in', style: TextInputStyle.short, label: "Reminder in", isRequired: true),
    TextInputBuilder(customId: 'message', style: TextInputStyle.paragraph, label: 'Message', isRequired: false)
  ]);

  final inParameterValue = modal['in'];
  if (inParameterValue == null) {
    return context.respond(MessageBuilder(content: "Missing in parameter"), level: ResponseLevel.private);
  }

  final offset = parseStringToDuration(inParameterValue);
  if (offset == null) {
    return context.respond(MessageBuilder(content: "Invalid value for `Reminder in` parameter"),
        level: ResponseLevel.private);
  }

  var message = modal['message'];
  if (message == null || message.isEmpty) {
    message = 'See attached message';
  }

  final triggerAt = DateTime.now().add(offset);
  _createReminder(
      userId: context.user.id,
      channelId: context.channel.id,
      messageId: context.targetMessage.id,
      triggerAt: triggerAt,
      message: message);

  context.respond(MessageBuilder(content: _getReminderReadyMessageText(context.user.mention, triggerAt, message)));
});

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
          ..write(' Creating reminder: ')
          ..write(triggerAt.format(TimestampStyle.relativeTime))
          ..write(': ')
          ..write(message);

        final replyMessage = await context.respond(MessageBuilder(content: messageBuffer.toString()));

        await _createReminder(
          userId: context.user.id,
          channelId: context.channel.id,
          messageId: replyMessage.id,
          triggerAt: triggerAt,
          message: message,
        );

        final editMessageContent = _getReminderReadyMessageText(context.user.mention, triggerAt, message);
        await replyMessage.edit(MessageUpdateBuilder(content: editMessageContent));
      }),
    ),
    ChatCommand(
      'clear',
      'Remove all your reminders',
      id('reminder-clear', (ChatContext context) async {
        Injector.appInstance.get<ReminderModule>().removeAllRemindersForUser(context.user.id);

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
        await Injector.appInstance.get<ReminderModule>().removeReminder(reminder);

        await context.respond(MessageBuilder(content: 'Successfully removed your reminder.'));
      }),
    ),
    ChatCommand(
      'list',
      'List all your active reminders',
      id('reminder-list', (ChatContext context) async {
        final reminders = Injector.appInstance.get<ReminderModule>().getUserReminders(context.user.id).toList()
          ..sort((a, b) => a.triggerAt.compareTo(b.triggerAt));

        final entries = reminders.asMap().entries.map((entry) {
          final index = entry.key;
          final reminder = entry.value;

          final embed =
              EmbedBuilder(color: getRandomColor(), title: 'Reminder ${index + 1} of ${reminders.length}', fields: [
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
