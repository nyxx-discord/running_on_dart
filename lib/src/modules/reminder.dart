import 'dart:async';

import 'package:fuzzy/fuzzy.dart';
import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';
import 'package:running_on_dart/src/models/reminder.dart';
import 'package:running_on_dart/src/repository/reminder.dart';

class ReminderModuleComponentId {
  static String identifier = 'ReminderModuleComponentId';

  final int reminderId;
  final Snowflake userId;
  final Duration duration;

  ReminderModuleComponentId({required this.reminderId, required this.userId, required this.duration});

  static ReminderModuleComponentId? parse(String idString) {
    final idParts = idString.split("/");

    if (idParts.isEmpty || idParts.first != identifier) {
      return null;
    }

    return ReminderModuleComponentId(
        reminderId: int.parse(idParts[1]),
        userId: Snowflake.parse(idParts[2]),
        duration: Duration(minutes: int.parse(idParts[3])));
  }

  @override
  String toString() => "$identifier/$reminderId/$userId/${duration.inMinutes}";
}

class ReminderModule {
  final List<Reminder> reminders = [];

  final Logger _logger = Logger('ROD.ReminderModule');
  final NyxxGateway _client = Injector.appInstance.get();
  final ReminderRepository _reminderRepository = Injector.appInstance.get();

  ReminderModule() {
    _reminderRepository.fetchReminders().then((reminders) => this.reminders.addAll(reminders));

    _processCurrent();

    _client.onMessageComponentInteraction
        .where((event) => event.interaction.data.type == MessageComponentType.button)
        .listen(_listenForReminderButtonEvent);
  }

  Future<void> _processCurrent() async {
    await _executeScheduled();

    Timer(const Duration(seconds: 1), _processCurrent);
  }

  Future<void> _executeScheduled() async {
    final now = DateTime.now();

    _logger.fine('Processing reminders for $now');

    final executionResults =
        reminders.where((reminder) => reminder.triggerAt.isBefore(now)).toList().map((reminder) => _execute(reminder));

    await Future.wait(executionResults);
  }

  Future<void> _execute(Reminder reminder) async {
    _logger.fine('Executing reminder ${reminder.id}');

    final channel = await _client.channels[reminder.channelId].getOrNull();

    if (channel != null && channel is TextChannel) {
      await _sendReminderMessage(reminder, channel);
    }

    await removeReminder(reminder);
  }

  Future<void> _sendReminderMessage(Reminder reminder, TextChannel channel) async {
    final content = StringBuffer('<@!${reminder.userId}> Reminder ')
      ..write(reminder.addedAt.format(TimestampStyle.relativeTime))
      ..write(" (${reminder.addedAt.format(TimestampStyle.shortDateTime)})")
      ..write(": ")
      ..write(reminder.message);

    final buttons = [5, 15, 30, 60]
        .map((minutes) => Duration(minutes: minutes))
        .map((duration) => ButtonBuilder.primary(
            customId: ReminderModuleComponentId(reminderId: reminder.id!, userId: reminder.userId, duration: duration)
                .toString(),
            label: "Add ${duration.inMinutes} mins"))
        .toList();

    final messageBuilder = MessageBuilder(
        content: content.toString(), replyId: reminder.messageId, components: [ActionRowBuilder(components: buttons)]);

    await channel.sendMessage(messageBuilder);
  }

  Future<void> _listenForReminderButtonEvent(InteractionCreateEvent<MessageComponentInteraction> event) async {
    final data = event.interaction.data;

    final customId = ReminderModuleComponentId.parse(data.customId);
    if (customId == null) {
      return;
    }

    final targetUserId = event.interaction.member?.id ?? event.interaction.user?.id;

    if (targetUserId == null) {
      return event.interaction
          .respond(MessageBuilder(content: "Invalid interaction. Missing user id!"), isEphemeral: true);
    }

    if (targetUserId != customId.userId) {
      return event.interaction.respond(MessageBuilder(content: "You cannot use this button!"), isEphemeral: true);
    }

    final reminder = await _reminderRepository.fetchReminder(customId.reminderId);
    if (reminder == null) {
      return event.interaction
          .respond(MessageBuilder(content: "Given reminder is missing. Cannot extend reminder!"), isEphemeral: true);
    }

    final newReminder = await addReminder(Reminder.fromOther(reminder, DateTime.now().add(customId.duration)));

    return event.interaction.respond(
        MessageBuilder(
            content:
                "Reminder extended ${customId.duration.inMinutes} minutes. Will trigger at: ${newReminder.triggerAt.format(TimestampStyle.longDateTime)}."),
        isEphemeral: true);
  }

  /// Add a new reminder to the database and schedule its execution.
  Future<Reminder> addReminder(Reminder reminder) async {
    await _reminderRepository.addReminder(reminder);

    _logger.fine('Added reminder ${reminder.id} to the database');

    reminders.add(reminder);

    return reminder;
  }

  /// Delete a reminder from the database and cancel its execution.
  Future<void> removeReminder(Reminder reminder) async {
    reminders.remove(reminder);
  }

  /// Get all the reminders for a specific user.
  Iterable<Reminder> getUserReminders(Snowflake userId) => reminders.where((reminder) => reminder.userId == userId);

  /// Search reminders for a specific user
  Iterable<Reminder> search(Snowflake userId, String query) {
    final results = Fuzzy<Reminder>(
      getUserReminders(userId).toList(),
      options: FuzzyOptions(
        keys: [
          WeightedKey(
            name: 'message',
            getter: (reminder) =>
                reminder.message.length < 50 ? reminder.message : '${reminder.message.substring(0, 50)}...',
            weight: 1,
          ),
          WeightedKey(
            name: 'timestamp',
            getter: (reminder) => reminderDateFormat.format(reminder.triggerAt),
            weight: 1,
          ),
          WeightedKey(
            name: 'Perfect match',
            getter: (reminder) =>
                '${reminderDateFormat.format(reminder.triggerAt)}  ${reminder.message.length < 50 ? reminder.message : '${reminder.message.substring(0, 50)}...'}',
            weight: 2,
          ),
        ],
        // We perform our own search later
        shouldSort: false,
      ),
    ).search(query);

    results.sort((a, b) {
      final difference = a.item.triggerAt.difference(b.item.triggerAt);
      final weight = difference.inDays.abs() / 10;

      if (difference.isNegative) {
        return a.score.compareTo(b.score * weight);
      } else {
        return (a.score * weight).compareTo(b.score);
      }
    });

    return results.map((result) => result.item);
  }
}
