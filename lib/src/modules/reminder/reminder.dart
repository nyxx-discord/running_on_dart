import "dart:async";

import "package:logging/logging.dart";
import "package:nyxx/nyxx.dart";
import "package:nyxx_interactions/interactions.dart";
import "package:running_on_dart/src/internal/db.dart" as db;
import "package:running_on_dart/src/modules/reminder/reminder_entity.dart";

Logger _logger = Logger("ROD - Reminder");

List<ReminderEntity> _remindersCache = [];
late Nyxx _client;

Future<void> initReminderModule(Nyxx nyxx) async {
  _client = nyxx;
  _logger.info("Starting reminder module");

  await syncRemindersCache();

  Timer.periodic(const Duration(seconds: 30), (timer) => syncRemindersCache());
  Timer.periodic(const Duration(seconds: 1), (timer) => executeRemindersCache());
}

Future<void> executeRemindersCache() async {
  final remindersLength = _remindersCache.length;
  if (remindersLength == 0) {
    return;
  }

  final now = DateTime.now();

  for (var i = 0; i < remindersLength; i++) {
    final entry = _remindersCache[i];

    if (now.difference(entry.triggerDate).inMilliseconds.abs() < 1000) {
      unawaited(_client.httpEndpoints.sendMessage(entry.channelId, getMessageBuilderForReminder(entry)));
      _remindersCache.removeAt(i);
    }
  }

  final remindersDifference = remindersLength - _remindersCache.length;
  if (remindersDifference > 0) {
    _logger.info("[$remindersDifference] reminders executed successfully");
  }
}

MessageBuilder getMessageBuilderForReminder(ReminderEntity reminderEntity) {
  final content = "Reminder: <t:${reminderEntity.addDate.millisecondsSinceEpoch ~/ 1000}:R>: ${reminderEntity.message}";

  final builder = ComponentMessageBuilder()..content = content;

  return builder;
}

Future<void> syncRemindersCache() async {
  _logger.info("Syncing reminder cache");
  _remindersCache = await fetchCurrentReminders().toList();
  _logger.info("Synced reminder cache. Number of entries: ${_remindersCache.length}");
}

Future<ReminderEntity?> fetchReminder(int id) async {
  const query = """
    SELECT r.* FROM reminders r WHERE r.id = @id;
  """;

  final dbResult = await db.connection.query(query, substitutionValues: {"id": id});

  if (dbResult.isEmpty) {
    return null;
  }

  return ReminderEntity(dbResult.first.toColumnMap());
}

Stream<ReminderEntity> fetchCurrentReminders() async* {
  const query = """
    SELECT r.* FROM reminders r WHERE r.trigger_date > NOW() AND r.active = TRUE;
  """;

  final dbResult = await db.connection.query(query);

  for (final dbRow in dbResult) {
    yield ReminderEntity(dbRow.toColumnMap());
  }
}

Stream<ReminderEntity> fetchCurrentRemindersForUser(Snowflake userId) async* {
  const query = """
    SELECT r.* FROM reminders r WHERE r.trigger_date > NOW() AND r.user = @userId AND r.active = TRUE;
  """;

  final dbResult = await db.connection.query(query, substitutionValues: {"userId": userId});

  for (final dbRow in dbResult) {
    yield ReminderEntity(dbRow.toColumnMap());
  }
}

Future<bool> createReminder(Snowflake userId, Snowflake channelId, DateTime triggerDate, String message, {Snowflake? messageId}) async {
  const query = """
    INSERT INTO reminders (user_id, channel_id, message_id, add_date, trigger_date, message, active)
    VALUES (@userId, @channelId, @messageId, CURRENT_TIMESTAMP, @triggerDate, @message, TRUE) RETURNING id;
  """;

  final resultingId = await db.connection.query(query, substitutionValues: {
    "userId": userId.toString(),
    "channelId": channelId.toString(),
    "messageId": messageId?.toString(),
    "triggerDate": triggerDate.toIso8601String(),
    "message": message
  });

  final result = resultingId.first.first as int?;
  if (result != null) {
    final reminder = await fetchReminder(result);

    if (reminder == null) {
      return false;
    }

    _remindersCache.add(reminder);
  }

  return true;
}

Iterable<ReminderEntity> fetchRemindersForUser(Snowflake userId) =>
    _remindersCache.where((element) => element.userId == userId && element.active == true).take(6);

Future<int> clearRemindersForUser(Snowflake userId) async {
  const query = """
    UPDATE reminders 
    SET active = FALSE
    WHERE user_id = @userId
  """;

  final result = await db.connection.execute(query, substitutionValues: {"userId": userId.toString()});

  if (result > 0) {
    _remindersCache.removeWhere((element) => element.userId == userId);
  }

  return result;
}

Future<bool> removeReminderForUser(int id, Snowflake userId) async {
  const query = """
    UPDATE reminders 
    SET active = FALSE
    WHERE user_id = @userId AND id = @id
  """;

  final result = await db.connection.execute(query, substitutionValues: {"userId": userId.toString(), "id": id});

  if (result > 0) {
    _remindersCache.removeWhere((element) => element.id == 15 && element.userId == userId);
  }

  return result == 1;
}
