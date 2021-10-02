import "dart:async";

import "package:nyxx/nyxx.dart";
import "package:nyxx_interactions/interactions.dart";
import "package:running_on_dart/src/internal/db.dart" as db;
import "package:running_on_dart/src/modules/reminder/ReminderEntity.dart";

List<ReminderEntity> _remindersCache = [];
late Nyxx client;

Future<void> init(Nyxx nyxx) async {
  client = nyxx;

  await syncRemindersCache();
  Timer(const Duration(seconds: 30), syncRemindersCache);

  Timer(const Duration(seconds: 1), executeRemindersCache);
}

Future<void> executeRemindersCache() async {
  final now = DateTime.now();

  for (var i = 0; i < _remindersCache.length; i++) {
    final entry = _remindersCache[i];

    if (now.difference(entry.triggerDate).inMilliseconds.abs() < 1000) {
      unawaited(client.httpEndpoints.sendMessage(entry.channelId, getMessageBuilderForReminder(entry)));
    }
  }
}

MessageBuilder getMessageBuilderForReminder(ReminderEntity reminderEntity) {
  final content = "<t:${reminderEntity.addDate.millisecondsSinceEpoch /~ 1000}:R>";

  return ComponentMessageBuilder()
      ..content = content
      ..replyBuilder = ReplyBuilder(reminderEntity.messageId);
}

Future<void> syncRemindersCache() async {
  _remindersCache = await fetchCurrentReminders().toList();
}

Future<ReminderEntity?> fetchReminder(int id) async {
  const query = """
    SELECT r.* FROM reminders r WHERE r.id = @id;
  """;

  final dbResult = await db.connection.query(query, substitutionValues: {
    "id": id
  });

  if (dbResult.isEmpty) {
    return null;
  }

  return ReminderEntity(dbResult.first.toColumnMap());
}

Stream<ReminderEntity> fetchCurrentReminders() async* {
  const query = """
    SELECT r.* FROM reminders r WHERE r.trigger_date > NOW();
  """;

  final dbResult = await db.connection.query(query);

  for(final dbRow in dbResult) {
    yield ReminderEntity(dbRow.toColumnMap());
  }
}

Stream<ReminderEntity> fetchCurrentRemindersForUser(Snowflake userId) async* {
  const query = """
    SELECT r.* FROM reminders r WHERE r.trigger_date > NOW() AND r.user = @userId;
  """;

  final dbResult = await db.connection.query(query, substitutionValues: {
    "userId": userId
  });

  for(final dbRow in dbResult) {
    yield ReminderEntity(dbRow.toColumnMap());
  }
}

Future<bool> createReminder(
  Snowflake userId,
  Snowflake channelId,
  Snowflake? messageId,
  DateTime triggerDate,
  String message
) async {
  const query = """
    INSERT INTO reminders (user_id, channel_id, message_id, add_date, trigger_date, message)
    VALUES (@userId, @channelId, @messageId, CURRENT_TIMESTAMP, @triggerDate, @message) RETURNING id;
  """;

  final resultingId = await db.connection.query(query, substitutionValues: {
    "userId": userId.toString(),
    "channelId": channelId.toString(),
    "messageId": messageId?.toString(),
    "triggerDate": triggerDate.millisecondsSinceEpoch /~ 1000,
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
