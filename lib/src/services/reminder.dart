import 'dart:async';

import 'package:fuzzy/fuzzy.dart';
import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/reminder.dart';
import 'package:running_on_dart/src/services/db.dart';

class ReminderService {
  static ReminderService get instance => _instance ?? (throw Exception('Reminder service must be initialised with Reminder.init'));
  static ReminderService? _instance;

  final List<Reminder> reminders = [];

  final Logger _logger = Logger('ROD.Reminders');
  final INyxxWebsocket _client;

  ReminderService._(this._client) {
    DatabaseService.instance.fetchReminders().then((reminders) => this.reminders.addAll(reminders));

    _processCurrent();
  }

  static void init(INyxxWebsocket client) {
    _instance = ReminderService._(client);
  }

  Future<void> _processCurrent() async {
    await _executeScheduled();

    Timer(const Duration(seconds: 1), _processCurrent);
  }

  Future<void> _executeScheduled() async {
    final now = DateTime.now();

    _logger.fine('Processing reminders for $now');

    final executionResults = <Future<void>>[];

    // Convert reminders we are running to a separate list to avoid a concurrent modification exception
    for (final reminder in reminders.where((reminder) => reminder.triggerAt.isBefore(now)).toList()) {
      executionResults.add(_execute(reminder));
    }

    await Future.wait(executionResults);
  }

  Future<void> _execute(Reminder reminder) async {
    _logger.fine('Executing reminder ${reminder.id}');

    final channel = _client.channels.values.whereType<ITextChannel?>().firstWhere((channel) => channel?.id == reminder.channelId, orElse: () => null);

    if (channel != null) {
      try {
        await channel.sendMessage(
          MessageBuilder()
            ..append('<@!${reminder.userId}> Reminder ')
            ..appendTimestamp(reminder.addedAt, style: TimeStampStyle.relativeTime)
            ..append(': ')
            ..append(reminder.message)
            ..replyBuilder = reminder.messageId != null ? ReplyBuilder(reminder.messageId!, false) : null,
        );
      } on IHttpResponseError {
        // Message was too long to be sent.
        _logger.warning('Reminder ${reminder.id} exceeded message length');
      }
    }

    reminders.remove(reminder);
  }

  /// Add a new reminder to the database and schedule its execution.
  Future<void> addReminder(Reminder reminder) async {
    await DatabaseService.instance.addReminder(reminder);

    _logger.fine('Added reminder ${reminder.id} to the database');

    reminders.add(reminder);
  }

  /// Delete a reminder from the database and cancel its execution.
  Future<void> removeReminder(Reminder reminder) async {
    await DatabaseService.instance.deleteReminder(reminder);

    _logger.fine('Removed reminder ${reminder.id} from the database');

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
            getter: (reminder) => reminder.message.length < 50 ? reminder.message : reminder.message.substring(0, 50) + '...',
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
                '${reminderDateFormat.format(reminder.triggerAt)}  ${reminder.message.length < 50 ? reminder.message : reminder.message.substring(0, 50) + '...'}',
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
