import 'dart:async';

import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/models/reminder.dart';

import 'db.dart' as database;

final List<Reminder> reminders = [];

late final INyxxWebsocket _client;

final Logger _logger = Logger('ROD.Reminders');

/// Initialise the reminders service.
Future<void> initReminders(INyxxWebsocket client) async {
  _client = client;

  for (final reminder in await database.fetchReminders()) {
    reminders.add(reminder);
  }

  _processCurrent();
}

Future<void> _processCurrent() async {
  await _executeScheduled();

  Timer(const Duration(seconds: 1), _processCurrent);
}

Future<void> _executeScheduled() async {
  final DateTime now = DateTime.now();

  _logger.fine('Processing reminders for $now');

  List<Future<void>> executionResults = [];

  // Convert reminders we are running to a seperate list to avoid a concurrent modification exception
  for (final reminder in reminders.where((reminder) => reminder.triggerAt.isBefore(now)).toList()) {
    executionResults.add(_execute(reminder));
  }

  await Future.wait(executionResults);
}

Future<void> _execute(Reminder reminder) async {
  _logger.fine('Executing reminder ${reminder.id}');

  ITextChannel? channel = _client.channels.values.whereType<ITextChannel?>().firstWhere((channel) => channel?.id == reminder.channelId, orElse: () => null);

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

Future<void> addReminder(Reminder reminder) async {
  await database.addReminder(reminder);

  _logger.fine('Added reminder ${reminder.id} to the database');

  reminders.add(reminder);
}

Future<void> removeReminder(Reminder reminder) async {
  await database.deleteReminder(reminder);

  _logger.fine('Removed reminder ${reminder.id} from the database');

  reminders.remove(reminder);
}

Iterable<Reminder> getUserReminders(Snowflake userId) => reminders.where((reminder) => reminder.userId == userId);
